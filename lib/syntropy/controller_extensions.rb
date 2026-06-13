# frozen_string_literal: true

require 'securerandom'

module Syntropy
  # Utilities for use in modules
  module ControllerExtensions
    # Returns a unique temporary path
    #
    # @param prefix [String] temp file prefix
    # @return [String]
    def tmp_path(prefix = 'syntropy')
      "/tmp/#{prefix}-#{SecureRandom.hex(16)}"
    end

    # Returns a request handler that routes request according to the host
    # header. Looks for site directories (named by host name) in the app's root
    # directory. A map may be given in order to provide additional hostnames to
    # site directories.
    #
    # @param dir [String, nil] relative directory path for host sites
    # @param map [Hash, nil] hash mapping host names to relative site directory
    # @return [Proc] router proc
    def dispatch_by_host(dir = nil, map = nil)
      raise Syntropy::Error, 'Must provide dir and/or map' if !dir && !map

      site_map = {}
      setup_directory_sites(dir, site_map) if dir
      setup_mapped_sites(map, site_map) if map

      ->(req) do
        site = site_map[req.host]
        site ? site.call(req) : req.respond(nil, ':status' => HTTP::BAD_REQUEST)
      end
    end

    # Returns a request handler that handles requests by calling the appropriate
    # module method (e.g. get, post, etc.)
    #
    # @return [Proc]
    def dispatch_by_http_method
      ->(req) do
        route_by_http_method(req)
      end
    end

    # Returns a list of parsed markdown pages at the given path.
    #
    # @param env [Hash] app environment hash
    # @param ref [String] directory path
    # @return [Array<Hash>] array of page entries
    def page_list(env, ref)
      full_path = File.join(env[:app_root], ref)
      raise 'Not a directory' if !File.directory?(full_path)

      Dir[File.join(full_path, '*.md')].sort.map {
        atts, markdown = Syntropy::Markdown.parse(it, env)
        { atts:, markdown: }
      }
    end

    # Instantiates a Syntropy app for the given environment hash.
    #
    # @return [Syntropy::App]
    def app(**)
      Syntropy::App.new(**)
    end

    BUILTIN_APPLET_app_root = File.expand_path(File.join(__dir__, 'applets/builtin'))

    # Creates a builtin applet with the given environment hash. By default the
    # builtin applet is mounted at /.syntropy.
    #
    # @param env [Hash] app environment
    # @param mount_path [String] mount path for the builtin applet
    # @return [Syntropy::App] applet
    def builtin_applet(env, mount_path: '/.syntropy')
      app(
        machine:    env[:machine],
        app_root:   BUILTIN_APPLET_app_root,
        mount_path: mount_path,
        builtin_applet_path: nil,
        watch_files: nil
      )
    end

    private

    # Finds sites in the root directory for the given environment hash, adds
    # entries to the given site map.
    #
    # @param dir [String] relative or absolute path
    # @param site_map [Hash] site map
    # @return [void]
    def setup_directory_sites(ref, site_map)
      app_root = @app ? @app.app_root : @env[:app_root]
      ref = normalize_import_ref(ref)

      Dir[File.join(app_root, ref, '*')]
        .select { File.directory?(it) && File.basename(it) !~ /^_/ }
        .each { |entry| site_map[File.basename(entry)] = make_app(entry) }
    end

    # converts the given map entries by adding entries to the given site map.
    #
    # @param map [Hash] ref map
    # @param site_map [Hash] site map
    # @return [void]
    def setup_mapped_sites(map, site_map)
      app_root = @app ? @app.app_root : @env[:app_root]
      map.each do |name, ref|
        ref = File.join(File.dirname(@ref), ref) if ref !~ /^\//
        site_root = File.join(app_root, ref)
        site_map[name] = make_app(site_root)
      end
    end

    # Creates an app loaded from the given root directory, with the present
    # mount path.
    def make_app(site_root)
      mount_path = @ref == '/_site' ? '/' : @ref
      env = @env.merge(app_root: site_root, mount_path:)
      Syntropy::App.new(**env)
    end

    # Handles the given request by calling the module method corresponding to
    # the request's HTTP method. If no method is found, raises a
    # method_not_allowed error.
    def route_by_http_method(req)
      sym = req.method.to_sym
      raise Syntropy::Error.method_not_allowed if !respond_to?(sym)

      send(sym, req)
    end
  end
end
