# frozen_string_literal: true

module Syntropy
  # Utilities for use in modules
  module Utilities
    # Returns a request handler that routes request according to the host
    # header. Looks for site directories (named by host name) in the app's root
    # directory. A map may be given in order to provide additional hostnames to
    # site directories.
    #
    # @param env [Hash] app environment hash
    # @param map [Hash, nil] additional hostname map
    # @return [Proc] router proc
    def route_by_host(env, map = nil)
      sites = find_hostname_sites(env)

      # add map refs
      map&.each { |k, v| sites[k] = sites[v] }

      lambda { |req|
        site = sites[req.host]
        site ? site.call(req) : req.respond(nil, ':status' => HTTP::BAD_REQUEST)
      }
    end

    # Returns a list of parsed markdown pages at the given path.
    #
    # @param env [Hash] app environment hash
    # @param ref [String] directory path
    # @return [Array<Hash>] array of page entries
    def page_list(env, ref)
      full_path = File.join(env[:root_dir], ref)
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

    BUILTIN_APPLET_ROOT_DIR = File.expand_path(File.join(__dir__, 'applets/builtin'))

    # Creates a builtin applet with the given environment hash. By default the
    # builtin applet is mounted at /.syntropy.
    #
    # @param env [Hash] app environment
    # @param mount_path [String] mount path for the builtin applet
    # @return [Syntropy::App] applet
    def builtin_applet(env, mount_path: '/.syntropy')
      app(
        machine:    env[:machine],
        root_dir:   BUILTIN_APPLET_ROOT_DIR,
        mount_path: mount_path,
        builtin_applet_path: nil,
        watch_files: nil
      )
    end

    private

    # Finds sites in the root directory for the given environment hash.
    #
    # @param env [Hash] app environment hash
    # @return [Hash] hash mapping hostname to app
    def find_hostname_sites(env)
      Dir[File.join(env[:root_dir], '*')]
        .select { File.directory?(it) && File.basename(it) !~ /^_/ }
        .each_with_object({}) { |fn, h|
          name = File.basename(fn)
          h[name] = Syntropy::App.new(**env.merge(root_dir: fn))
        }
    end
  end
end
