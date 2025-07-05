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
      mod_ctx.loader = self
      mod_ctx.env = @env
      mod_ctx.module_eval(mod_body, fn, 1)

      export_value = mod_ctx.__export_value__

      wrap_module(mod_ctx, export_value)
    end

    def wrap_module(mod_ctx, export_value)
      case export_value
      when nil
        raise 'No export found'
      when Symbol
        # TODO: verify export_value denotes a valid method
        mod_ctx.new(@env)
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

    def self.loader=(loader)
      @loader = loader
    end

    def self.env=(env)
      @env = env
    end

    def self.import(ref)
      @loader.load(ref)
    end

    def self.export(ref)
      @__export_value__ = ref
    end

    def self.template(&block)
      Papercraft.html(&block)
    end

    def self.route_by_host
      root = @env[:location]
      sites = Dir[File.join(root, '*')]
        .select { File.directory?(it) }
        .inject({}) { |h, fn|
          name = File.basename(fn)
          opts = @env.merge(location: fn)
          h[name] = Syntropy::App.new(opts[:machine], opts[:location], opts[:mount_path], opts)
          h
        }
      ->(req) {
        site = sites[req.host]
        site ? site.call(req) : req.respond(nil, ':status' => Status::BAD_REQUEST)
      }
    end

    def self.__export_value__
      @__export_value__
    end

  end
end
