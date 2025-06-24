# frozen_string_literal: true

module Syntropy
  class ModuleLoader
    def initialize(root, env)
      @root = root
      @env = env
      @loaded = {}
    end

    def load(ref)
      @loaded[ref] ||= load_module(ref)
    end

    private

    def load_module(ref)
      fn = File.join(@root, "#{ref}.rb")
      raise RuntimeError, "File not found #{fn}" if !File.file?(fn)

      mod_body = IO.read(fn)
      mod_ctx = Class.new(Syntropy::Module)
      mod_ctx.loader = self
      # mod_ctx = .new(self, @env)
      mod_ctx.module_eval(mod_body, fn, 1)

      export_value = mod_ctx.__export_value__

      case export_value
      when nil
        raise RuntimeError, 'No export found'
      when Symbol
        # TODO: verify export_value denotes a valid method
        mod_ctx.new(@env)
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

    def self.import(ref)
      @loader.load(ref)
    end

    def self.export(ref)
      @__export_value__ = ref
    end

    def self.__export_value__
      @__export_value__
    end
  end
end
