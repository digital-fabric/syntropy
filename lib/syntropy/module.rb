# frozen_string_literal: true

require 'papercraft'

module Syntropy
  # The ModuleLoader class implemenets a module loader. It handles loading of
  # modules, tracking of dependencies between modules, and invalidation of
  # loaded modules (following a change to the module file).
  #
  # A module may implement a route endpoint, a layout template, utility methods,
  # classes, or any other functionality needed by the web app.
  #
  # Modules are Ruby files that can import other modules as dependencies. A
  # module must export a single value, which can be a class, a template, a proc,
  # or any other Ruby object. A module can also export itself by calling `export
  # self`.
  #
  # Modules are referenced relative to the web app's root directory, without the
  # `.rb` extension. For example, for a site residing in `/my_site`, the
  # reference `_lib/foo` will point to a module residing in
  # `/my_site/_lib/foo.rb`.
  class ModuleLoader
    attr_reader :modules

    # Instantiates a module loader
    #
    # @param env [Hash] environment hash
    # @return [void]
    def initialize(env)
      @root_dir = env[:root_dir]
      @env = env
      @modules = {} # maps ref to module entry
      @fn_map = {} # maps filename to ref
    end

    # Loads a module (if not already loaded) and returns its export value.
    #
    # @param ref [String] module reference
    # @return [any] export value
    def load(ref)
      ref = "/#{ref}" if ref !~ /^\//

      entry = (@modules[ref] ||= load_module(ref))
      entry[:export_value]
    end

    # Invalidates a module by its filename, normally following a change to the
    # underlying file (in order to cause reloading of the module). The module
    # will be removed from the modules map, as well as modules dependending on
    # it.
    #
    # @param fn [String] module filename
    # @return [void]
    def invalidate_fn(fn)
      ref = @fn_map[fn]
      invalidate_ref(ref) if ref
      invalidate_collection_modules
    end

    private

    # Invalidates a module by its reference, normally following a change to the
    # underlying file (in order to cause reloading of the module). The module
    # will be removed from the modules map, as well as modules dependending on
    # it.
    #
    # @param ref [String] module reference
    # @return [void]
    def invalidate_ref(ref)
      entry = @modules.delete(ref)
      return if !entry

      @fn_map.delete(entry[:fn])
      entry[:reverse_deps].each { invalidate_ref(it) }
    end

    def invalidate_collection_modules
      refs = []
      @modules.each do |ref, entry|
        refs << ref if entry[:module].is_collection_module?
      end
      refs.each { invalidate_ref(it) }
    end

    # Registers reverse dependencies for the given module reference.
    #
    # @param ref [String] module reference
    # @param deps [Array<String>] array of dependencies for the given module
    # @return [void]
    def add_dependencies(ref, deps)
      deps.each do
        entry = @modules[it]
        next if !entry

        entry[:reverse_deps] << ref
      end
    end

    # Loads a module and returns a module entry. Any dependencies (using
    # `import`) are loaded as well.
    #
    # @param ref [String] module reference
    # @return [Hash] module entry
    def load_module(ref)
      ref = "/#{ref}" if ref !~ /^\//
      fn = File.expand_path(File.join(@root_dir, "#{ref}.rb"))
      raise Syntropy::Error, "File not found #{fn}" if !File.file?(fn)

      @fn_map[fn] = ref
      code = IO.read(fn)
      env = @env.merge(module_loader: self, ref: clean_ref(ref))
      mod = Syntropy::Module.load(env, code, fn)
      add_dependencies(ref, mod.__dependencies__)
      export_value = transform_module_export_value(mod.__export_value__)

      {
        fn: fn,
        module: mod,
        export_value: export_value,
        reverse_deps: []
      }
    end

    def clean_ref(ref)
      return '/' if ref =~ /^index(\+)?$/

      clean = ref.gsub(/\/index(?:\+)?$/, '')
      clean == '' ? '/' : clean
    end

    # Transforms the given export value. If the value is nil, an exception is
    # raised.
    #
    # @param export_value [any] module's export value
    # @return [any] transformed value
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

  # The Syntropy::Module class implements a reloadable module. A module is a
  # `.rb` source file that implements a route endpoint, a template, utility
  # methods or any other functionality needed by the web app.
  #
  # The following instance variables are available to modules:
  #
  # - `@env`: the app environment hash
  # - `@machine`: a reference to the UringMachine instance
  # - `@module_loader`: a reference to the module loader
  # - `@app`: a reference to the app
  # - `@ref`: the module's logical path (path relative to the app root)
  # - `@logger`: a reference to the app's logger
  #
  # In addition, the module code also has access to the `MODULE` constant which
  # is set to `self`, and may be used to refer to various methods defined in the
  # module.
  class Module
    # Loads a module, returning the module instance
    def self.load(env, code, fn)
      m = new(**env)
      m.instance_eval(code, fn)
      env[:logger]&.info(message: "Loaded module at #{fn}")
      m
    end

    # Initializes a module with the given environment hash.
    #
    # @param env [Hash] environment hash
    # @return [void]
    def initialize(**env)
      @env = env
      @machine = env[:machine]
      @module_loader = env[:module_loader]
      @app = env[:app]
      @ref = env[:ref]
      @logger = env[:logger]
      @__dependencies__ = []
      singleton_class.const_set(:MODULE, self)
    end

    attr_reader :__export_value__, :__dependencies__

    # Returns a list of pages found at the given ref.
    #
    # @param ref [String] directory reference
    # @return [Array] array of pages found in directory
    def page_list(ref)
      Syntropy.page_list(@env, ref)
    end

    # Returns true if the module is a collection module. See also
    # #collection_module!
    #
    # @return [bool]
    def is_collection_module?
      @collection_module_p
    end

    private

    # Exports the given value. This value will be used as the module's
    # entrypoint. It can be any Ruby value, but for a route module would
    # normally be a proc.
    #
    # @param v [any] export value
    # @return [void]
    def export(v)
      @__export_value__ = v
    end

    # Imports the module corresponding to the given reference. The return value
    # is the module's export value.
    #
    # @param ref [String] module reference
    # @return [any] loaded dependency's export value
    def import(ref)
      ref = normalize_import_ref(ref)
      @module_loader.load(ref).tap { __dependencies__ << ref }
    end

    # Marks module as a collection module. This will cause the module to be
    # invalidated on every file change in dev mode, regardless if it is a
    # dependency.
    #
    # @return [self]
    def collection_module!
      @collection_module_p = true
      self
    end

    def normalize_import_ref(ref)
      base = @ref == '' ? '/' : @ref
      if ref =~ /^\//
        ref
      else
        File.expand_path(File.join(File.dirname(base), ref))
      end
    end

    # Creates and returns a Papercraft template created with the given block.
    #
    # @param proc [Proc, nil] template proc or nil
    # @param block [Proc] template block
    # @return [Papercraft::Template] template
    def template(proc = nil, &block)
      proc ||= block
      raise "No template block/proc given" if !proc

      Papercraft::Template.new(proc)
    end

    # Creates and returns a Papercraft XML template created with the given block.
    #
    # @param proc [Proc, nil] template proc or nil
    # @param block [Proc] template block
    # @return [Papercraft::Template] template
    def template_xml(proc = nil, &block)
      proc ||= block
      raise "No template block/proc given" if !proc

      Papercraft::Template.new(proc, mode: :xml)
    rescue => e
      p e
      p e.backtrace
      raise
    end

    # Creates and returns a Syntropy app for the given environment. The app's
    # environment is based on the module's env merged with the given parameters.
    #
    # @param env [Hash] environment
    def app(**env)
      env = @env.merge(env)
      Syntropy::App.new(**env)
    end
  end
end
