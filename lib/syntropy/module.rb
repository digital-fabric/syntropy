# frozen_string_literal: true

require 'p2'

module Syntropy
  class ModuleLoader
    def initialize(env)
      @root_dir = env[:root_dir]
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
      fn = File.expand_path(File.join(@root_dir, "#{ref}.rb"))
      @fn_map[fn] = ref
      raise Syntropy::Error, "File not found #{fn}" if !File.file?(fn)

      code = IO.read(fn)
      env = @env.merge(module_loader: self, ref: ref)
      export_value = Syntropy::Module.load(env, code, fn)
      transform_module_export_value(export_value)
    end

    def transform_module_export_value(export_value)
      case export_value
      when nil
        raise Syntropy::Error, 'No export found'
      when String
        ->(req) { req.respond(export_value) }
      when Class
        export_value.new(@env)
      else
        export_value
      end
    end
  end

  class Module
    def self.load(env, code, fn)
      m = new(**env)
      m.instance_eval(code, fn)
      export_value = m.__export_value__
      env[:logger]&.info(message: "Loaded module at #{fn}")
      export_value
    rescue StandardError => e
      env[:logger]&.error(
          message: "Error while loading module #{fn}",
          error: e
      )
      raise
    end

    attr_reader
    def initialize(**env)
      @env = env
      @machine = env[:machine]
      @module_loader = env[:module_loader]
      @app = env[:app]
      @ref = env[:ref]
      singleton_class.const_set(:MODULE, self)
    end

    attr_reader :__export_value__
    def export(v)
      @__export_value__ = v
    end

    def import(ref)
      @module_loader.load(ref)
    end

    def template(proc = nil, &block)
      proc ||= block
      raise "No template block/proc given" if !proc

      P2::Template.new(proc)
    end

    def page_list(ref)
      Syntropy.page_list(@env, ref)
    end

    def app(**env)
      Syntropy::App.new(**(@env.merge(env)))
    end
  end
end
