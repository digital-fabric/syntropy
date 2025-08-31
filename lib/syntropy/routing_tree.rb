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
      @static_map.freeze
      @dynamic_map.freeze
    end

    # Returns the generated router proc for the routing tree
    #
    # @return [Proc] router proc
    def router_proc
      @router_proc ||= compile_router_proc
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

    # Generates and returns a router proc based on the routing tree.
    #
    # @return [Proc] router proc
    def compile_router_proc
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
      buffer << "# frozen_string_literal: true\n"

      emit_code_line(buffer, '->(path, params) {')
      emit_code_line(buffer, '  entry = @static_map[path]; return entry if entry')
      emit_code_line(buffer, '  parts = path.split("/")')

      if @root[:path] != '/'
        root_parts = @root[:path].split('/')
        segment_idx = root_parts.size
        validate_parts = []
        (1..(segment_idx - 1)).each do |i|
          validate_parts << "(parts[#{i}] != #{root_parts[i].inspect})"
        end
        emit_code_line(buffer, "  return nil if #{validate_parts.join(' || ')}")
      else
        segment_idx = 1
      end

      visit_routing_tree_entry(buffer:, entry: @root, segment_idx:)

      emit_code_line(buffer, "  return nil")
      emit_code_line(buffer, "}")
      buffer#.tap { puts '*' * 40; puts it; puts }
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

      # Get next segment
      emit_code_line(buffer, "#{ws}case (p = parts[#{segment_idx}])")

      # In case of no next segment
      emit_code_line(buffer, "#{ws}when nil")
      if entry[:target]
        map = entry[:static] ? '@static_map' : '@dynamic_map'
        emit_code_line(buffer, "#{ws}  return #{map}[#{entry[:path].inspect}]")
      else
        emit_code_line(buffer, "#{ws}  return nil")
      end

      if entry[:children]
        param_entry = entry[:children]['[]']
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
            route_value = "@dynamic_map[#{child_entry[:path].inspect}]"
            emit_code_line(buffer, "#{ws}  return #{route_value}#{if_clause}")

          elsif has_children
            # otherwise look at the next segment
            next if is_void_route?(child_entry) && !param_entry

            emit_code_line(buffer, "#{ws}when #{k.inspect}")
            visit_routing_tree_entry(buffer:, entry: child_entry, indent: indent + 1, segment_idx: segment_idx + 1)
          end
        end

        # parametric route
        if param_entry
          emit_code_line(buffer, "#{ws}else")
          emit_code_line(buffer, "#{ws}  params[#{param_entry[:param].inspect}] = p")
          visit_routing_tree_entry(buffer:, entry: param_entry, indent: indent + 1, segment_idx: segment_idx + 1)
        end
      end
      emit_code_line(buffer, "#{ws}end")
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
      return false if entry[:param]

      if entry[:children]
        return true if !entry[:children]['[]'] && entry[:children]&.values&.all? { is_void_route?(it) }
      else
        return true if entry[:static]
      end

      false
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
