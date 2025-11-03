# frozen_string_literal: true

module Syntropy
  # The RoutingTree class implements a file-based routing tree with support for
  # static files, markdown files, ruby modules, parametric routes, subtree routes,
  # nested middleware and error handlers.
  #
  # A RoutingTree instance takes the given directory (root_dir) and constructs a
  # tree of route entries corresponding to the directory's contents. Finally, it
  # generates an optimized router proc, which is used by the application to return
  # a route entry for each incoming HTTP request.
  #
  # Once initialized, the routing tree is immutable. When running Syntropy in
  # watch mode, whenever a file or directory is changed, added or deleted, a new
  # routing tree will be constructed, and the old one will be discarded.
  #
  # File-based routing in Syntropy follows some simple rules:
  #
  # - Static files (anything other than markdown files or dynamic Ruby modules)
  #   are routed to according to their location in the file tree.
  # - Index files with  `.md` or `.rb` extension handle requests to their
  #   immediate containing directory. For example, `/users/index.rb` will handle
  #   requests to `/users`.
  # - Index files with a `+` suffix will also handle requests to anywhere in their
  #   subtree. For example, `/users/index+.rb` will also handle requests to
  #   `/users/foo/bar`.
  # - Other markdown and module files will handle requests to their bare name
  #   (that is, without the extension.) Thus, `/users/foo.rb` will handle requests
  #   to `/users/foo`. A route with a `+` suffix will also handle requests to the
  #   route's subtree. Thus, `/users/foo+.rb` will also handle requests to
  #   `/users/foo/bar`.
  # - Parametric routes are implemented by enclosing the route name in square
  #   brackets. For example, `/processes/[proc_id]/index.rb` will handle requests
  #   to `/posts/14` etc. Parametric route parts can also be expressed as files,
  #   e.g. `/processes/[id]/sources/[src_id].rb` will handle requests to
  #   `/posts/14/sources/42` etc. The values for placeholders are added to the
  #   incoming request. Here too, a `+` suffix causes the route to also handle
  #   requests to its subtree.
  # - Directories and files whose names start with an underscore, e.g. `/_foo` or
  #   `/docs/_bar.rb` are skipped and will not be added to the routing tree. This
  #   allows you to prevent access through the HTTP server to protected or
  #   internal modules or files.
  class RoutingTree
    attr_reader :root_dir, :mount_path, :static_map, :dynamic_map, :root

    # Initializes a new RoutingTree instance and computes the routing tree
    #
    # @param root_dir [String] root directory of file tree
    # @param mount_path [String] base URL path
    # @return [void]
    def initialize(root_dir:, mount_path:, **env)
      @root_dir = root_dir
      @mount_path = mount_path
      @static_map = {}
      @dynamic_map = {}
      @env = env
      @root = compute_tree
    end

    # Returns the generated router proc for the routing tree
    #
    # @return [Proc] router proc
    def router_proc
      @router_proc ||= generate_router_proc
    end

    # Computes a "clean" URL path for the given path. Modules and markdown are
    # stripped of their extensions, and index file paths are also converted to the
    # containing directory path. For example, the clean URL path for `/foo/bar.rb`
    # is `/foo/bar`. The Clean URL path for `/bar/baz/index.rb` is `/bar/baz`.
    #
    # @param fn [String] file path
    # @return [String] clean path
    def compute_clean_url_path(fn)
      rel_path = fn.sub(@root_dir, '')
      case rel_path
      when /^(.*)\/index\.(md|rb|html)$/
        Regexp.last_match(1).then { it == '' ? '/' : it }
      when /^(.*)\.(md|rb|html)$/
        Regexp.last_match(1)
      else
        rel_path
      end
    end

    # Converts filename to relative path.
    #
    # @param fn [String] filename
    # @return [String] relative path
    def fn_to_rel_path(fn)
      fn.sub(/^#{Regexp.escape(@root_dir)}\//, '').sub(/\.[^\.]+$/, '')
    end

    # Mounts the given applet on the routng tree at the given (absolute) mount
    # path. This method must be called before the router proc is generated.
    #
    # @param path [String] absolute mount path for the applet
    # @param applet [Syntropy::App, Proc] applet
    # @return [void]
    def mount_applet(path, applet)
      path = rel_mount_path(path)
      mount_applet_on_tree(@root, path, applet)
    end

    private

    # Maps extensions to route kind.
    FILE_TYPE = {
      '.rb' => :module,
      '.md' => :markdown
    }

    # Computes the routing tree, returning the root entry. Route entries are
    # represented as hashes with the following keys:
    #
    # - `:parent` - reference to the parent entry.
    # - `:path` - the URL path for the entry.
    # - `:target` - a hash containing route target information.
    # - `:param` - the parameter name for parametric routes.
    # - `:hook` - a reference to the hook module (`_hook.rb`) for the directory,
    #   if exists.
    # - `:error` - a reference to the error handler module (`_error.rb`) for the
    #   directory, if exists.
    # - `children` - a hash mapping segment names to the corresponding child
    #   entries.
    #
    # Route entries are created for any directory, and for any *dynamic* files
    # (i.e. markdown or Ruby module files). Files starting with `_` are not
    # considered as routes and will not be included in the routing tree. Static
    # files will also not be included in the routing tree, but instead will be
    # mapped in the static file map (see below).
    #
    # The routing tree is complemented with two maps:
    #
    # - `static_map` - maps URL paths to the corresponding static route entries,
    #   which includes all non-parametric routes, as well as all static files.
    # - `dynamic_map` - maps URL paths to the corresponding parametric route
    #   entries.
    #
    # The reason we use two separate maps is to prevent accidentally hitting a
    # false lookup for a a URL with segments containing square brackets!
    #
    # @return [Hash] root entry
    def compute_tree
      compute_route_directory(dir: @root_dir, rel_path: '/', parent: nil)
    end

    # Converts the given absolute path to a relative one (relative to the
    # routing tree's mount path).
    #
    # @param path [String] absolute mount path
    # @return [String] relative mount path
    def rel_mount_path(path)
      if @mount_path == '/'
        path.sub(/^\//, '')
      else
        path.sub(/^#{Regexp.escape(@mount_path)}\//, '')
      end
    end

    # Mounts the given applet as a child of the given entry. If the given
    # (relative) path is nested, drills down the given entry's subtree and
    # automatically creates intermediate children entries. If a child entry
    # already exists for the given path, an error is raised. The given applet
    # may be an instance of `Syntropy::App` or a proc.
    #
    # @param entry [Hash] route entry on which to mount the applet
    # @param path [String] relative path
    # @param applet [Syntropy::App, Proc] applet
    # @return [void]
    def mount_applet_on_tree(entry, path, applet)
      if (m = path.match(/^([^\/]+)\/(.+)$/))
        child_entry = find_or_create_child_entry(entry, m[1])
        mount_applet_on_tree(child_entry, m[2], applet)
      else
        child_entry = entry[:children] && entry[:children][path]
        raise Syntropy::Error, "Could not mount applet, entry already exists" if child_entry

        applet_path = File.join(entry[:path], path)
        applet_entry = {
          parent: entry,
          path: applet_path,
          handle_subtree: true,
          target: { kind: :module },
          proc: applet
        }

        (entry[:children] ||= {})[path] = applet_entry
        @dynamic_map[applet_path] = applet_entry
      end
    end

    # Finds or creates a child entry with the given name on the given parent
    # entry.
    #
    # @param parent [Hash] parent entry
    # @param name [String] child's name
    # @return [Hash] child entry
    def find_or_create_child_entry(parent, name)
      parent[:children] ||= {}
      parent[:children][name] ||= {
        parent: parent,
        path: File.join(parent[:path], name),
        children: {}
      }
    end

    # Computes a route entry for a directory.
    #
    # @param dir [String] directory path
    # @param rel_path [String] relative directory path
    # @param parent [Hash, nil] parent entry
    def compute_route_directory(dir:, rel_path:, parent: nil)
      param = (m = File.basename(dir).match(/^\[(.+)\]$/)) ? m[1] : nil
      entry = {
        parent:,
        path:       rel_path_to_abs_path(rel_path),
        param:,
        hook:       find_aux_module_entry(dir, '_hook.rb'),
        error:      find_aux_module_entry(dir, '_error.rb')
      }
      entry[:children] = compute_child_routes(
        dir:, rel_path:, parent: entry
      )
      entry
    end

    # Searches for a file of the given name in the given directory. If found,
    # returns the file path.
    #
    # @param dir [String] directory path
    # @param name [String] filename
    # @return [String, nil] file path if found
    def find_aux_module_entry(dir, name)
      fn = File.join(dir, name)
      File.file?(fn) ? ({ kind: :module,  fn: }) : nil
    end

    # Returns a hash mapping file/dir names to route entries.
    #
    # @param dir [String] directory path to scan for files
    # @param rel_path [String] directory path relative to root directory
    # @param parent [Hash] directory's corresponding route entry
    def compute_child_routes(dir:, rel_path:, parent:)
      file_search(dir).each_with_object({}) { |fn, map|
        next if File.basename(fn) =~ /^_/

        rel_path = compute_clean_url_path(fn)
        child = if File.file?(fn)
          compute_route_file(fn:, rel_path:, parent:)
        elsif File.directory?(fn)
          compute_route_directory(dir: fn, rel_path:, parent:)
        end
        map[child_key(child)] = child if child
      }
    end

    # Returns all entries in the given dir.
    #
    # @param dir [String] directory path
    # @return [Array<String>] array of file entries
    def file_search(dir)
      Dir[File.join(dir.gsub(/[\[\]]/) { "\\#{it}"}, '*')]
    end

    # Computes a route entry and/or target for the given file path.
    #
    # @param fn [String] file path
    # @param rel_path [String] relative path
    # @param parent [Hash, nil] parent entry
    # @return [void]
    def compute_route_file(fn:, rel_path:, parent:)
      abs_path = rel_path_to_abs_path(rel_path)

      # index.rb, index+.rb, index.md
      case
      when (m = fn.match(/\/index(\+)?(\.(?:rb|md))$/))
        make_index_module_route(m:, parent:, path: abs_path, fn:)

      # index.html
      when fn.match(/\/index\.html$/)
        set_index_route_target(parent:, path: abs_path, kind: :static, fn:)

      # foo.rb, foo+.rb, foo.md, [foo].rb, [foo]+.rb
      when (m = fn.match(/\/(\[)?([^\]\/\+]+)(\])?(\+)?(\.(?:rb|md))$/))
        make_module_route(m:, parent:, path: abs_path, fn:)

      # everything else
      else
        # static files resolved using the static map, and are not added to the
        # routing tree, which is used for resolving dynamic routes. HTML files
        # are routed by their clean URL, i.e. without the `.html` extension.
        target = { kind: :static, fn: }
        make_route_entry(parent:, path: abs_path, target:)
      end
    end

    # Creates a route entry for an index module (ruby/markdown). Index files
    # (modules or markdown) files) are applied as targets to the immediate
    # containing directory. A + suffix indicates this route handles requests to
    # its subtree
    #
    # @param m [MatchData] path match data
    # @param parent [Hash] parent route entry
    # @param path [String] route path
    # @param fn [String] route target filename
    # @return [nil] (prevents addition of an index route)
    def make_index_module_route(m:, parent:, path:, fn:)
      plus, ext = m[1..2]
      kind = FILE_TYPE[ext]
      handle_subtree = (plus == '+') && (kind == :module)
      if handle_subtree
        path = path.gsub(/\/index\+$/, '')
        path = '/' if path.empty?
      end
      set_index_route_target(parent:, path:, kind:, fn:, handle_subtree:)
    end


    # Sets an index route target for the given parent entry. Index files are
    # applied as targets to the immediate containing directory. HTML index files
    # are considered static and therefore not added to the routing tree.
    #
    # @param parent [Hash] parent route entry
    # @param path [String] route path
    # @param kind [Symbol] route target kind
    # @param fn [String] route target filename
    # @param handle_subtree [bool] whether the target handles the subtree
    # @return [nil] (prevents addition of an index route)
    def set_index_route_target(parent:, path:, kind:, fn:, handle_subtree: nil)
      if is_parametric_route?(parent) || handle_subtree
        @dynamic_map[path] = parent
        parent[:target] = { kind:, fn: }
        parent[:handle_subtree] = handle_subtree
      else
        @static_map[path] = {
          parent: parent[:parent],
          path:,
          target: { kind:, fn: },
          # In case we're at the tree root, we need to copy over the hook and
          # error refs.
          hook: !parent[:parent] && parent[:hook],
          error: !parent[:parent] && parent[:error]
        }
      end
      nil
    end

    # Creates a route entry for normal module and markdown files. A + suffix
    # indicates the module also handles requests to the subtree. For example,
    # `/foo/bar.rb` will handle requests to `/foo/bar`, but `/foo/bar+.rb` will
    # also handle requests to `/foo/bar/baz/bug`.
    #
    # parametric, or wildcard, routes convert segments of the URL path into
    # parameters that are added to the HTTP request. Parametric routes are
    # denoted using square brackets around the file/directory name. For example,
    # `/api/posts/[id].rb`` will handle requests to `/api/posts/42`, and will
    # extract the parameter `posts => 42` to add to the incoming request.
    #
    # A + suffix indicates the module also handles the subtree, so e.g.
    # `/api/posts/[id]+.rb` will also handle requests to `/api/posts/42/fans`
    # etc.
    #
    # @param m [MatchData] path match data
    # @param parent [Hash] parent route entry
    # @param path [String] route path
    # @param fn [String] route target filename
    # @return [Hash] route entry
    def make_module_route(m:, parent:, path:, fn:)
      ob, param, cb, plus, ext = m[1..5]
      kind = FILE_TYPE[ext]
      make_route_entry(
        parent:, path:, param: ob && cb ? param : nil,
        target: { kind:, fn: },
        handle_subtree: (plus == '+') && (kind == :module)
      )
    end

    # Creates a new route entry, registering it in the static or dynamic map,
    # according to its type.
    #
    # @param entry [Hash] route entry
    def make_route_entry(entry)
      path = entry[:path]
      if is_parametric_route?(entry) || entry[:handle_subtree]
        @dynamic_map[path] = entry
      else
        entry[:static] = true
        @static_map[path] = entry
      end
    end

    # returns true if the route or any of its ancestors are parametric.
    #
    # @param entry [Hash] route entry
    def is_parametric_route?(entry)
      entry[:param] || (entry[:parent] && is_parametric_route?(entry[:parent]))
    end

    # Converts a relative URL path to absolute URL path.
    #
    # @param rel_path [String] relative path
    # @return [String] absolute path
    def rel_path_to_abs_path(rel_path)
      rel_path == '/' ? @mount_path : File.join(@mount_path, rel_path)
    end

    # Returns the key for the given route entry to be used in its parent's
    # children map.
    #
    # @param entry [Hash] route entry
    # @return [String] child key
    def child_key(entry)
      entry[:param] ? '[]' : File.basename(entry[:path]).gsub(/\+$/, '')
    end

    # Freezes the static and dynamic maps, generates and returns a router proc
    # based on the routing tree.
    #
    # @return [Proc] router proc
    def generate_router_proc
      @static_map.freeze
      @dynamic_map.freeze
      code = generate_routing_tree_code
      eval(code, binding, '(router)', 1)
    end

    # Generates the router proc source code. The router proc code is dynamically
    # generated from the routing tree, converting the routing tree structure into
    # Ruby proc of the following signature:
    #
    # ```ruby
    # # @param path [String] URL path
    # # @param params [Hash] Hash receiving parametric route values
    # # @return [Hash, nil] route entry
    # ->(path, params) { ... }
    # ```
    #
    # The generated code performs the following tasks:
    #
    # - Test if the given path corresponds to a static file (using `@static_map`)
    # - Otherwise, split the given path into path segments
    # - Walk through the path segments according to the routing tree structure
    # - Emit parametric route values to the `params` hash
    # - Return the found route entry
    #
    # @return [String] router proc code to be `eval`ed
    def generate_routing_tree_code
      buffer = +''
      buffer << "# frozen_string_literal: true\n\n"

      wildcard_root = @root[:handle_subtree]
      childless_root = !@root[:children] || @root[:children].empty?

      if wildcard_root && childless_root
        emit_wildcard_childless_root_code(buffer, @root[:path])
      else
        emit_router_proc_prelude(buffer)
        segment_idx = 1
        if @root[:path] != '/'
          root_parts = @root[:path].split('/')
          segment_idx = root_parts.size
          emit_root_validate_guard(buffer:, root_parts:)
        end

        visit_routing_tree_entry(buffer:, entry: @root, segment_idx:)
        emit_router_proc_postlude(buffer, default_route_path: wildcard_root && @root[:path])
      end

      buffer#.tap { puts '*' * 40; puts it; puts }
    end

    # Emits optimized code for a childless wildcard router.
    #
    # @param buffer [String] output buffer
    # @param root_path [String] router root path
    # @return [void]
    def emit_wildcard_childless_root_code(buffer, root_path)
      emit_code_line(buffer, '->(path, params) {')
      if root_path != '/'
        re = /^#{Regexp.escape(root_path)}(\/.*)?$/
        emit_code_line(buffer, "  return if path !~ #{re.inspect}")
      end
      emit_code_line(buffer, "  @dynamic_map[#{root_path.inspect}]")
      emit_code_line(buffer, '}')
    end

    # Emits router proc prelude code.
    #
    # @param buffer [String] output buffer
    # @return [void]
    def emit_router_proc_prelude(buffer)
      emit_code_line(buffer, '->(path, params) {')
      emit_code_line(buffer, '  entry = @static_map[path]; return entry if entry')
      emit_code_line(buffer, '  parts = path.split("/")')
    end

    # Emits root path validation guard code.
    #
    # @param buffer [String] output buffer
    # @param root_parts [Array<String>] root path parts
    # @return [void]
    def emit_root_validate_guard(buffer:, root_parts:)
      validate_parts = []
      (1...root_parts.size).each do |i|
        validate_parts << "(parts[#{i}] != #{root_parts[i].inspect})"
      end
      emit_code_line(buffer, "  return nil if #{validate_parts.join(' || ')}")
    end

    # Emits router proc postlude code.
    #
    # @param buffer [String] output buffer
    # @param default_route_path [String, nil] default route path
    # @return [void]
    def emit_router_proc_postlude(buffer, default_route_path:)
      if default_route_path
        emit_code_line(buffer, "  return @dynamic_map[#{default_route_path.inspect}]")
      else
        emit_code_line(buffer, "  return nil")
      end
      emit_code_line(buffer, "}")
    end

    # Generates routing logic code for the given route entry.
    #
    # @param buffer [String] buffer receiving code
    # @param entry [Hash] route entry
    # @param indent [Integer] indent level
    # @param segment_idx [Integer] path segment index
    # @return [void]
    def visit_routing_tree_entry(buffer:, entry:, indent: 1, segment_idx:)
      ws = ' ' * (indent * 2)

      # If no targets exist in the entry's subtree, we can return nil
      # immediately.
      if !entry[:target] && !find_target_in_subtree(entry)
        emit_code_line(buffer, "#{ws}return nil")
        return
      end

      if is_void_route?(entry)
        parent = entry[:parent]
        parametric_sibling = parent && parent[:children] && parent[:children]['[]']
        if parametric_sibling
          emit_code_line(buffer, "#{ws}return nil")
          return
        end
      end

      return if !entry[:target] && !entry[:children]

      if entry[:target] && entry[:handle_subtree] && !entry[:children]
        map = entry[:static] ? '@static_map' : '@dynamic_map'
        emit_code_line(buffer, "#{ws}return #{map}[#{entry[:path].inspect}]")
        return
      end

      case_buffer = +''
      if entry[:target]
        emit_code_line(case_buffer, "#{ws}when nil")
        map = entry[:static] ? '@static_map' : '@dynamic_map'
        emit_code_line(case_buffer, "#{ws}  return #{map}[#{entry[:path].inspect}]")
      end
      if entry[:children]
        emit_routing_tree_entry_children_clauses(buffer: case_buffer, entry:, indent:, segment_idx:)
      end

      # Get next segment
      if !case_buffer.empty?
        emit_code_line(buffer, "#{ws}case (p = parts[#{segment_idx}])")
        buffer << case_buffer
        emit_code_line(buffer, "#{ws}end")
      end
    end

    # Returns the first target found in the given entry's subtree.
    #
    # @param entry [Hash] route entry
    # @return [Hash, nil] route target if exists
    def find_target_in_subtree(entry)
      entry[:children]&.values&.each { |e|
        target = e[:target] || find_target_in_subtree(e)
        return target if target
      }

      nil
    end

    # Returns true if the given route is not parametric, has no children and is
    # static, or has children and all are void.
    #
    # @param entry [Hash] route entry
    # @return [bool]
    def is_void_route?(entry)
      return false if entry[:param] || entry[:target]

      if entry[:children]
        return true if !entry[:children]['[]'] && entry[:children]&.values&.all? { is_void_route?(it) }
      else
        return true if entry[:static]
      end

      false
    end

    # Emits case clauses for the given entry's children.
    #
    # @param buffer [String] output buffer
    # @param entry [Hash] route entry
    # @param indent [Integer] indent level
    # @param segment_idx [Integer] path segment index
    # @return [void]
    def emit_routing_tree_entry_children_clauses(buffer:, entry:, indent:, segment_idx:)
      ws = ' ' * (indent * 2)

      param_entry = entry[:children]['[]']
      when_count = 0
      entry[:children].each do |k, child_entry|
        # skip if wildcard entry (treated in else clause below)
        next if k == '[]'

        # skip if entry is void (no target, no children)
        has_target = child_entry[:target]
        has_children = child_entry[:children] && !child_entry[:children].empty?
        next if !has_target && !has_children

        if has_target && !has_children
          # use the target
          next if child_entry[:static]

          emit_code_line(buffer, "#{ws}when #{k.inspect}")
          if_clause = child_entry[:handle_subtree] ? '' : " if !parts[#{segment_idx + 1}]"

          child_path = child_entry[:path]
          route_value = "@dynamic_map[#{child_path.inspect}]"
          emit_code_line(buffer, "#{ws}  return #{route_value}#{if_clause}")
          when_count += 1

        elsif has_children
          # otherwise look at the next segment
          next if is_void_route?(child_entry) && !param_entry

          when_buffer = +''
          visit_routing_tree_entry(buffer: when_buffer, entry: child_entry, indent: indent + 1, segment_idx: segment_idx + 1)
          if when_buffer.empty? && param_entry
            emit_code_line(when_buffer, "#{ws}  return nil")
          end
          if !when_buffer.empty?
            emit_code_line(buffer, "#{ws}when #{k.inspect}")
            buffer << when_buffer
            when_count += 1
          end
        end
      end

      # parametric route
      if param_entry
        if when_count == 0
          emit_code_line(buffer, "#{ws}when p")
        else
          emit_code_line(buffer, "#{ws}else")
        end

        emit_code_line(buffer, "#{ws}  params[#{param_entry[:param].inspect}] = p")
        visit_routing_tree_entry(buffer:, entry: param_entry, indent: indent + 1, segment_idx: segment_idx + 1)
      # wildcard route
      elsif entry[:handle_subtree]
        emit_code_line(buffer, "#{ws}else")
        emit_code_line(buffer, "#{ws}  return @dynamic_map[#{entry[:path].inspect}]")
      end
    end

    DEBUG = !!ENV['DEBUG']

    # Emits the given code into the given buffer, with a line break at the end.
    # If the `DEBUG` environment variable is set, adds a source location comment
    # at the end of the line, referencing the callsite.
    #
    # @param buffer [String] code buffer
    # @param code [String] code
    # @return [void]
    def emit_code_line(buffer, code)
      if DEBUG
        loc = (m = caller[0].match(/^([^\:]+\:\d+)/)) && m[1]
        buffer << "#{code} # #{loc}\n"
      else
        buffer << "#{code}\n"
      end
    end
  end
end
