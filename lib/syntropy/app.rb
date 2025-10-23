# frozen_string_literal: true

require 'json'
require 'yaml'

require 'qeweney'
require 'papercraft'

require 'syntropy/errors'
require 'syntropy/file_watch'

require 'syntropy/module'
require 'syntropy/routing_tree'

module Syntropy
  class App
    class << self
      def load(env)
        site_file_app(env) || default_app(env)
      end

      private

      # for apps with a _site.rb file
      def site_file_app(env)
        fn = File.join(env[:root_dir], '_site.rb')
        return nil if !File.file?(fn)

        loader = Syntropy::ModuleLoader.new(env)
        loader.load('_site')
      end

      # default app
      def default_app(env)
        new(**env)
      end
    end

    attr_reader :module_loader, :routing_tree, :root_dir, :mount_path, :env

    def initialize(**env)
      @machine = env[:machine]
      @root_dir = File.expand_path(env[:root_dir])
      @mount_path = env[:mount_path]
      @env = env
      @logger = env[:logger]

      @module_loader = Syntropy::ModuleLoader.new(app: self, **env)
      setup_routing_tree
      start
    end

    # Processes an incoming HTTP request. Requests are processed by first
    # looking up the route for the request path, then calling the route proc. If
    # the route proc is not set, it is computed according to the route target,
    # and composed recursively into hooks encountered up the routing tree.
    #
    # Normal exceptions (StandardError and descendants) are trapped and passed
    # to route's error handler. If no such handler is found, the default error
    # handler is used, which simply generates a textual response containing the
    # error message, and with the appropriate HTTP status code, according to the
    # type of error.
    #
    # @param req [Qeweney::Request] HTTP request
    # @return [void]
    def call(req)
      route = @router_proc.(req.path, req.route_params)
      raise Syntropy::Error.not_found('Not found') if !route

      req.route = route
      proc = route[:proc] ||= compute_route_proc(route)
      proc.(req)
    rescue ScriptError, StandardError => e
      @logger&.error(
        message: "Error while serving request: #{e.message}",
        method: req.method,
        path: req.path,
        error: e
      )
      error_handler = get_error_handler(route)
      error_handler.(req, e)
    end

    # Returns the route entry for the given path. If compute_proc is true,
    # computes the route proc if not yet computed.
    #
    # @param path [String] path
    # @param params [Hash] hash receiving path parameters
    # @param compute_proc [bool] whether to compute the route proc
    # @return [Hash] route entry
    def route(path, params = {}, compute_proc: false)
      route = @router_proc.(path, params)
      return if !route

      route[:proc] ||= compute_route_proc(route) if compute_proc
      route
    end

    private

    # Instantiates a routing tree with the app settings, and generates a router
    # proc.
    #
    # @return [void]
    def setup_routing_tree
      @routing_tree = Syntropy::RoutingTree.new(
        root_dir: @root_dir, mount_path: @mount_path, **@env
      )
      mount_builtin_applet if @env[:builtin_applet_path]
      @router_proc = @routing_tree.router_proc
    end

    # Mounts the builtin applet on the routing tree.
    #
    # @return [void]
    def mount_builtin_applet
      path = @env[:builtin_applet_path]
      @builtin_applet ||= Syntropy.builtin_applet(@env, mount_path: path)
      @routing_tree.mount_applet(path, @builtin_applet)
    end

    # Computes the route proc for the given route, wrapping it in hooks found up
    # the routing tree.
    #
    # @param route [Hash] route entry
    # @return [Proc] route proc
    def compute_route_proc(route)
      pure = pure_route_proc(route)
      compose_up_tree_hooks(route, pure)
    end

    # Returns the pure route proc for the given route. A pure route proc is the
    # computed proc for the route without any middleware hooks.
    #
    # @param route [Hash] route entry
    # @return [Proc] route proc
    def pure_route_proc(route)
      case (kind = route[:target][:kind])
      when :static
        static_route_proc(route)
      when :markdown
        markdown_route_proc(route)
      when :module
        module_route_proc(route)
      else
        raise Syntropy::Error, "Invalid route kind: #{kind.inspect}"
      end
    end

    # Returns a proc rendering the given static route
    #
    # @param [Hash] route entry
    # @return [Proc] route handler proc
    def static_route_proc(route)
      fn = route[:target][:fn]
      headers = { 'Content-Type' => Qeweney::MimeTypes[File.extname(fn)] }

      ->(req) {
        case req.method
        when 'head'
          req.respond(nil, headers)
        when 'get'
          serve_static_file(req, route[:target])
        else
          raise Syntropy::Error.method_not_allowed
        end
      }
    end

    # Serves a static file from the given target hash with cache validation.
    #
    # @param req [Qeweney::Request] request
    # @param target [Hash] route target hash
    # @return [void]
    def serve_static_file(req, target)
      validate_static_file_info(target)
      cache_opts = {
        cache_control:  'max-age=3600',
        last_modified:  target[:last_modified_date],
        etag:           target[:etag]
      }
      req.validate_cache(**cache_opts) {
        req.respond(target[:content], 'Content-Type' => target[:mime_type])
      }
    rescue => e
      p e
      p e.backtrace
      exit!
    end

    # Validates and conditionally updates the file information for the given
    # target.
    #
    # @param target [Hash] route target hash
    # @return [void]
    def validate_static_file_info(target)
      now = Time.now
      return if target[:last_update] && ((Time.now - target[:last_update]) < 390)

      update_static_file_info(target, now)
    end

    STATX_MASK = UM::STATX_MTIME | UM::STATX_SIZE

    # Updates the static file information for the given target
    #
    # @param target [Hash] route target hash
    # @param now [Time] current time
    # @return [void]
    def update_static_file_info(target, now)
      target[:last_update] = now
      fd = @machine.open(target[:fn], UM::O_RDONLY)
      stat = @machine.statx(fd, nil, UM::AT_EMPTY_PATH, STATX_MASK)
      target[:size] = size = stat[:size]
      mtime = stat[:mtime].to_i
      return if target[:last_modified] == mtime # file not modified

      target[:last_modified] = mtime
      target[:last_modified_date] = Time.at(mtime).httpdate
      target[:content] = buffer = String.new(capacity: size)
      target[:mime_type] = Qeweney::MimeTypes[File.extname(target[:fn])]
      len = 0
      while len < size
        len += @machine.read(fd, buffer, size, len)
      end
      target[:etag] = Digest::SHA1.hexdigest(buffer)
    ensure
      @machine.close_async(fd) if fd
    end

    # Returns a proc rendering the given markdown route.
    #
    # @param route [Hash] route entry
    # @return [Proc] route proc
    def markdown_route_proc(route)
      headers = { 'Content-Type' => 'text/html' }

      ->(req) {
        req.respond_by_http_method(
          'head'  => [nil, headers],
          'get'   => -> { [render_markdown(route), headers] }
        )
      }
    end

    # Renders and returns the given markdown route as HTML.
    #
    # @param route [Hash] route entry
    # @return [String] rendered HTML
    def render_markdown(route)
      atts, md = Syntropy.parse_markdown_file(route[:target][:fn], @env)

      layout = compute_markdown_layout(route, atts)
      Papercraft.html(layout, md:, **atts)
    end

    def compute_markdown_layout(route, atts)
      if (layout = atts[:layout])
        route[:applied_layouts] ||= {}
        route[:applied_layouts][layout] ||= markdown_layout_template(layout)
      else
        default_markdown_layout_template
      end
    end

    # Returns a markdown template based on the given layout.
    #
    # @param layout [String] layout name
    # @return [Proc] layout template
    def markdown_layout_template(layout)
      @layouts ||= {}
      template = @module_loader.load("_layout/#{layout}")
      @layouts[layout] = Papercraft.apply(template) { |md:, **| markdown(md) }
    end

    # Returns the default markdown layout, which renders to HTML and includes a
    # title, the markdown content, and emits code for auto refreshing the page
    # on file change.
    #
    # @return [Proc] default Markdown layout template
    def default_markdown_layout_template
      @default_markdown_layout ||= ->(md:, **atts) {
        html5 {
          head {
            title atts[:title]
          }
          body {
            markdown md
            auto_refresh_watch! if @env[:dev_mode]
          }
        }
      }
    end

    # Returns the route proc for a module route.
    #
    # @param route [Hash] route entry
    # @return [Proc] route proc
    def module_route_proc(route)
      ref = @routing_tree.fn_to_rel_path(route[:target][:fn])
      mod = @module_loader.load(ref)
      compute_module_proc(mod)
    end

    # Computes a route proc for the given module. If the module is a template,
    # returns a route proc wrapping the template, otherwise the module itself is
    # considered as the route proc.
    #
    # @param mod [any] module value
    # @return [Proc] route proc
    def compute_module_proc(mod)
      case mod
      when Papercraft::Template
        papercraft_template_proc(mod)
      else
        mod
      end
    end

    # Returns a route proc for the given template.
    #
    # @param template [Papercraft::Template] template
    # @return [Proc] route proc
    def papercraft_template_proc(template)
      xml_mode = template.mode == :xml
      template = template.proc
      mime_type = xml_mode ? 'text/xml; charset=UTF-8' : 'text/html; charset=UTF-8'
      headers = { 'Content-Type' => mime_type }

      get_proc = xml_mode ?
        -> { [Papercraft.xml(template), headers] } :
        -> { [Papercraft.html(template), headers] }

      ->(req) {
        req.respond_by_http_method(
          'head'  => [nil, headers],
          'get'   => get_proc
        )
      }
    end

    # Composes the given proc into up tree hooks, recursively. Hooks have the
    # signature `->(req, proc) { ... }` where proc is the pure route proc. Each
    # hook therefore can decide whether to_ respond itself to the request, pass
    # in additional parameters, perform any other kind of modification on the
    # incoming reuqest, or capture the response from the route proc and modify
    # it.
    #
    # Nested hooks will be invoked from the routing tree root down. For example
    # `/site/_hook.rb` will wrap `/site/admin/_hook.rb` which wraps the route at
    # `/site/admin/users.rb`.
    #
    # @param route [Hash] route entry
    # @param proc [Proc] route proc
    def compose_up_tree_hooks(route, proc)
      hook_spec = route[:hook]
      if hook_spec
        orig_proc = proc
        hook_proc = hook_spec[:proc] ||= load_aux_module(hook_spec)
        proc = ->(req) { hook_proc.(req, orig_proc) }
      end

      (parent = route[:parent]) ? compose_up_tree_hooks(parent, proc) : proc
    end

    # Loads and returns an auxiliary module. This method is used for loading
    # hook modules.
    #
    # @param hook_spec [Hash] hook spec
    # @return [any] hook module
    def load_aux_module(hook_spec)
      ref = @routing_tree.fn_to_rel_path(hook_spec[:fn])
      @module_loader.load(ref)
    end

    # Returns an error handler for the given route. If route is nil, looks up
    # the error handler for the routing tree root. If no handler is found,
    # returns the default error handler.
    #
    # @param route [Hash] route entry
    # @return [Proc] error handler proc
    def get_error_handler(route)
      route_error_handler(route || @routing_tree.root) || default_error_handler
    end

    # Returns the given route's error handler, caching the result.
    #
    # @param route [Hash] route entry
    # @return [Proc] error handler proc
    def route_error_handler(route)
      route[:error_handler] ||= compute_error_handler(route)
    end

    # Finds and loads the error handler for the given route.
    #
    # @param route [Hash] route entry
    # @return [Proc, nil] error handler proc or nil
    def compute_error_handler(route)
      error_target = find_error_handler(route)
      return nil if !error_target

      load_aux_module(error_target)
    end

    # Finds the closest error handler for the given route. If no error handler
    # is defined for the route, searches for an error handler up the routing
    # tree.
    #
    # @param route [Hash] route entry
    # @return [Hash, nil] error handler target or nil
    def find_error_handler(route)
      return route[:error] if route[:error]

      route[:parent] && find_error_handler(route[:parent])
    end

    RAW_DEFAULT_ERROR_HANDLER = ->(req, err) {
      msg = err.message
      msg = nil if msg.empty? || (req.method == 'head')
      req.respond(msg, ':status' => Syntropy::Error.http_status(err)) rescue nil
    }

    def default_error_handler

      @default_error_handler ||= begin
        if @builtin_applet
          @builtin_applet.module_loader.load('/default_error_handler')
        else
          RAW_DEFAULT_ERROR_HANDLER
        end
      end
    end

    # Performs app start up, creating a log message and starting the file
    # watcher according to app options.
    #
    # @return [void]
    def start
      @machine.spin do
        # we do startup stuff asynchronously, in order to first let TP2 do its
        # setup tasks
        @machine.sleep 0.2
        route_count = @routing_tree.static_map.size + @routing_tree.dynamic_map.size
        @logger&.info(
          message: "Serving from #{@root_dir} (#{route_count} routes found)"
        )

        file_watcher_loop if @env[:watch_files]
      end
    end

    # Runs the file watcher loop. When a file change is encountered, invalidates
    # the corresponding module, and triggers recomputation of the routing tree.
    #
    # @return [void]
    def file_watcher_loop
      wf = @env[:watch_files]
      period = wf.is_a?(Numeric) ? wf : 0.1
      Syntropy.file_watch(@machine, @root_dir, period: period) do |event, fn|
        @logger&.info(message: 'File change detected', fn: fn)
        @module_loader.invalidate_fn(fn)
        debounce_file_change
      end
    rescue Exception => e
      p e
      p e.backtrace
      exit!
    end

    # Delays responding to a file change, then reloads the routing tree.
    #
    # @return [void]
    def debounce_file_change
      if @routing_tree_reloader
        @machine.schedule(@routing_tree_reloader, UM::Terminate.new)
      end

      @routing_tree_reloader = @machine.spin do
        @machine.sleep(0.1)
        setup_routing_tree
        @routing_tree_reloader = nil
        signal_auto_refresh_watchers!
      end
    end

    # Signals a file change to any auto refresh watchers.
    #
    # @return [void]
    def signal_auto_refresh_watchers!
      return if !@builtin_applet

      watcher_route_path = File.join(@env[:builtin_applet_path], 'auto_refresh/watch.sse')
      watcher_route = @builtin_applet.route(watcher_route_path, compute_proc: true)

      watcher_mod = watcher_route[:proc]
      watcher_mod.signal!
    rescue => e
      @logger&.error(
        message: 'Unexpected error while signalling auto refresh watcher',
        error: e
      )
    end
  end
end
