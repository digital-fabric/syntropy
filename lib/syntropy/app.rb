# frozen_string_literal: true

require 'json'
require 'yaml'

require 'qeweney'
require 'p2'

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

      @module_loader = Syntropy::ModuleLoader.new(app: self, **env)
      setup_routing_tree
      start_app
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
    rescue StandardError => e
      # p e
      # p e.backtrace
      error_handler = get_error_handler(route)
      error_handler.(req, e)
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
      @router_proc = @routing_tree.router_proc
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
    def static_route_proc(route)
      fn = route[:target][:fn]
      headers = { 'Content-Type' => Qeweney::MimeTypes[File.extname(fn)] }

      ->(req) {
        req.respond_by_http_method(
          'head'  => [nil, headers],
          'get'   => -> { [IO.read(fn), headers] }
        )
      }
    end

    # Returns a proc rendering the given markdown route
    def markdown_route_proc(route)
      headers = { 'Content-Type' => 'text/html' }

      ->(req) {
        req.respond_by_http_method(
          'head'  => [nil, headers],
          'get'   => -> { [render_markdown(route), headers] }
        )
      }
    end

    def render_markdown(route)
      atts, md = Syntropy.parse_markdown_file(route[:target][:fn], @env)

      if (layout = atts[:layout])
        route[:applied_layouts] ||= {}
        proc = route[:applied_layouts][layout] ||= markdown_layout_proc(layout)
        html = proc.render(md: md, **atts)
      else
        html = P2.markdown(md)
      end
      html
    end

    # returns a markdown template based on the given layout
    def markdown_layout_proc(layout)
      @layouts ||= {}
      template = @module_loader.load("_layout/#{layout}")
      @layouts[layout] = template.apply { |md:, **| markdown(md) }
    end

    def module_route_proc(route)
      ref = @routing_tree.fn_to_rel_path(route[:target][:fn])
      # ref = route[:target][:fn].sub(@mount_path, '')
      mod = @module_loader.load(ref)
      compute_module_proc(mod)
    end

    def compute_module_proc(mod)
      case mod
      when P2::Template
        p2_template_proc(mod)
      when Papercraft::Template
        papercraft_template_proc(mod)
      else
        mod
      end
    end

    def p2_template_proc(template)
      template = template.proc
      headers = { 'Content-Type' => 'text/html' }

      ->(req) {
        req.respond_by_http_method(
          'head'  => [nil, headers],
          'get'   => -> { [template.render, headers] }
        )
      }
    end

    def papercraft_template_proc(template)
        headers = { 'Content-Type' => template.mime_type }
      ->(req) {
        req.respond_by_http_method(
          'head'  => [nil, headers],
          'get'   => -> { [template.render, headers] }
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

    def load_aux_module(hook_spec)
      ref = @routing_tree.fn_to_rel_path(hook_spec[:fn])
      @module_loader.load(ref)
    end

    DEFAULT_ERROR_HANDLER = ->(req, err) {
      msg = err.message
      msg = nil if msg.empty? || (req.method == 'head')
      req.respond(msg, ':status' => Syntropy::Error.http_status(err))
    }

    # Returns an error handler for the given route. If route is nil, looks up
    # the error handler for the routing tree root. If no handler is found,
    # returns the default error handler.
    #
    # @param route [Hash] route entry
    # @return [Proc] error handler proc
    def get_error_handler(route)
      route_error_handler(route || @routing_tree.root) || DEFAULT_ERROR_HANDLER
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

    # Performs app start up, creating a log message and starting the file
    # watcher according to app options.
    #
    # @return [void]
    def start_app
      @machine.spin do
        # we do startup stuff asynchronously, in order to first let TP2 do its
        # setup tasks
        @machine.sleep 0.2
        @opts[:logger]&.info(
          message: "Serving from #{File.expand_path(@location)}"
        )
        file_watcher_loop if opts[:watch_files]
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
        @module_loader.invalidate(fn)
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
      end
    end
  end
end
