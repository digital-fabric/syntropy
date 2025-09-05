# frozen_string_literal: true

module Syntropy
  # Utilities for use in modules
  module Utilities
    # Returns a request handler that routes request according to
    def route_by_host(env, map = nil)
      root = env[:root_dir]
      sites = Dir[File.join(root, '*')]
              .reject { File.basename(it) =~ /^_/ }
              .select { File.directory?(it) }
              .each_with_object({}) { |fn, h|
                name = File.basename(fn)
                h[name] = Syntropy::App.new(**env.merge(root_dir: fn))
              }

      # copy over map refs
      map&.each { |k, v| sites[k] = sites[v] }

      #
      lambda { |req|
        site = sites[req.host]
        site ? site.call(req) : req.respond(nil, ':status' => Status::BAD_REQUEST)
      }
    end

    def page_list(env, ref)
      full_path = File.join(env[:root_dir], ref)
      raise 'Not a directory' if !File.directory?(full_path)

      Dir[File.join(full_path, '*.md')].sort.map {
        atts, markdown = Syntropy.parse_markdown_file(it, env)
        { atts:, markdown: }
      }
    end

    def app(**env)
      Syntropy::App.new(**env)
    end

    BUILTIN_APPLET_ROOT_DIR = File.expand_path(File.join(__dir__, 'applets/builtin'))
    def builtin_applet(env, mount_path: '/.syntropy')
      app(
        machine:    env[:machine],
        root_dir:   BUILTIN_APPLET_ROOT_DIR,
        mount_path: mount_path,
        builtin_applet_path: nil,
        watch_files: nil
      )
    end
  end
end
