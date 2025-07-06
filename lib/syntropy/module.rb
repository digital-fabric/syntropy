# frozen_string_literal: true

require 'papercraft'

module Syntropy
  class ModuleLoader
    def initialize(root, env)
      @root = root
      @env = env
      @loaded = {} # maps ref to code
      @fn_map = {} # maps filename to ref
    end

    def load(ref)
      @loaded[ref] ||= load_module(ref)
    end

    def invalidate(fn)
      ref = @fn_map[fn]
      return if !ref

      @loaded.delete(ref)
      @fn_map.delete(fn)
    end

    private

    def load_module(ref)
      fn = File.expand_path(File.join(@root, "#{ref}.rb"))
      @fn_map[fn] = ref
      raise "File not found #{fn}" if !File.file?(fn)

      mod_body = IO.read(fn)
      mod_ctx = Class.new(Syntropy::Module)
      mod_ctx.prepare(loader: self, env: @env)
      mod_ctx.module_eval(mod_body, fn, 1)

      export_value = mod_ctx.__export_value__

      wrap_module(mod_ctx, export_value)
    end

    def wrap_module(mod_ctx, export_value)
      case export_value
      when nil
        raise 'No export found'
      when Symbol
        o = mod_ctx.new(@env)
        # TODO: verify export_value denotes a valid method
        ->(req) { o.send(export_value, req) }
      when String
        ->(req) { req.respond(export_value) }
      when Proc
        export_value
      else
        export_value.new(@env)
      end
    end
  end

  class Module
    def initialize(env)
      @env = env
    end

    class << self
      def prepare(loader:, env:)
        @loader = loader
        @env = env
        const_set(:MODULE, self)
      end

      attr_reader :__export_value__

      def import(ref)
        @loader.load(ref)
      end

      def export(ref)
        @__export_value__ = ref
      end

      def template(&block)
        Papercraft.html(&block)
      end

      def route_by_host(map = nil)
        root = @env[:location]
        sites = Dir[File.join(root, '*')]
                .reject { File.basename(it) =~ /^_/ }
                .select { File.directory?(it) }
                .each_with_object({}) { |fn, h|
          name = File.basename(fn)
          opts = @env.merge(location: fn)
          h[name] = Syntropy::App.new(opts[:machine], opts[:location], opts[:mount_path], opts)
        }

        map&.each do |k, v|
          sites[k] = sites[v]
        end

        lambda { |req|
          site = sites[req.host]
          site ? site.call(req) : req.respond(nil, ':status' => Status::BAD_REQUEST)
        }
      end

      def page_list(ref)
        full_path = File.join(@env[:location], ref)
        raise 'Not a directory' if !File.directory?(full_path)

        Dir[File.join(full_path, '*.md')].sort.map {
          atts, markdown = Syntropy.parse_markdown_file(it, @env)
          { atts:, markdown: }
        }
      end
    end
  end
end
