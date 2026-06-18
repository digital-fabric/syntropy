# frozen_string_literal: true

require 'papercraft'
require 'syntropy/errors'

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
    # @param extensions [Module, Array<Module>] extension module(s)
    # @return [void]
    def initialize(env, extensions: nil)
      @env = env
      @app_root = env[:app_root]
      @modules = {} # maps ref to module entry
      @fn_map = {} # maps filename to ref
      @extensions = extensions
      @loading = Set.new
    end

    # Loads a module (if not already loaded) and returns its export value.
    #
    # @param ref [String] module reference
    # @return [any] export value
    def load(ref, raise_on_missing: true)
      ref = "/#{ref}" if ref !~ /^\//
      if !(entry = @modules[ref])
        entry = load_module(ref, raise_on_missing:)
        return if !entry

        @modules[ref] = entry
      end
      entry[:export_value]
    end

    # Returns a list of modules found in the given relative path. The module
    # references are returned as absolute paths (relative to the module loader
    # root directory).
    #
    # @param dir [String] relative module directory
    # @return [Array<String>] list of modules
    def list(dir)
      fns = Dir[File.join(@app_root, dir, '*.rb')]
      fns.map { it.match(/^#{@app_root}\/(.+)\.rb$/)[1] }.sort
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

    # Invalidates a collection module.
    #
    # @return [void]
    def invalidate_collection_modules
      refs = []
      @modules.each do |ref, entry|
        refs << ref if entry[:module].collection_module?
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
    def load_module(ref, raise_on_missing: true)
      ref = "/#{ref}" if ref !~ /^\//
      fn = File.expand_path(File.join(@app_root, "#{ref}.rb"))
      if !File.file?(fn)
        raise Syntropy::Error, "File not found #{fn}" if raise_on_missing

        return
      end

      raise Syntropy::Error, "Circular dependency detected" if @loading.include?(ref)
      do_load_module(ref, fn, raise_on_missing:)
    end

    def do_load_module(ref, fn, raise_on_missing:)
      @loading << ref
      @fn_map[fn] = ref
      code = read_file(fn)
      env = @env.merge(module_loader: self, ref: clean_ref(ref))
      mod = Syntropy::ModuleContext.load(env, code, fn, @extensions)
      add_dependencies(ref, mod.__dependencies__)
      export_value = transform_module_export_value(
        mod.__export_value__, fn, raise_on_missing:
      )

      {
        fn: fn,
        module: mod,
        export_value: export_value,
        reverse_deps: []
      }
    ensure
      @loading.delete(ref)
    end

    def read_file(fn)
      machine = @env[:machine]

      machine.open(fn, UM::O_RDONLY) { |fd|
        buf = +''
        res = machine.read(fd, buf, 1 << 20)
        buf
      }
    end

    # Cleans up a module reference specifier, turning /index into /
    #
    # @param ref [String] input ref
    # @return [String] clean ref
    def clean_ref(ref)
      return '/' if ref =~ /^index[+]?$/

      clean = ref.gsub(/\/index[+]?$/, '')
      (clean == '') ? '/' : clean
    end

    # Transforms the given export value. If the value is nil, an exception is
    # raised.
    #
    # @param export_value [any] module's export value
    # @return [any] transformed value
    def transform_module_export_value(export_value, fn, raise_on_missing:)
      case export_value
      when nil
        raise Syntropy::Error, "No export found in #{fn}" if raise_on_missing
      when String
        ->(req) { req.respond(export_value) }
      else
        export_value
      end
    end
  end

  # The Syntropy::ModuleContext class provides a context for loading a module. A
  # module is a `.rb` source file that implements a route endpoint, a template,
  # utility methods or any other functionality needed by the web app.
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
  class ModuleContext
    # Loads a module, returning the module instance
    # @param env [Hash] app environment
    # @param code [String] module source code
    # @param fn [String] module file name
    # @param extensions [Module, Array<Module>] extension module(s)
    # @return [Syntropy::ModuleContext] created module context
    def self.load(env, code, fn, extensions)
      mod = new(env)
      apply_extensions(mod, extensions)
      mod.instance_eval(code, fn)
      env[:logger]&.info(message: "Loaded module at #{fn}")
      mod
    rescue StandardError, SyntaxError => e
      env[:logger]&.error(message: "Error while loading module at #{fn}", error: e)
      e.is_a?(SyntaxError) ? handle_syntax_error(env, e) : (raise e)
    end

    # Applies the given extension(s) to the given module context.
    #
    # @param mod [Syntropy::ModuleContext] module context
    # @param extensions [Module, Array<Module>] extension module(s)
    def self.apply_extensions(mod, extensions)
      case extensions
      when Array
        extensions.each { mod.extend(it) }
      when Module
        mod.extend(extensions)
      when nil # return
      else
        raise Syntropy::Error, "Invalid module extensions: #{extensions.inspect}"
      end
    end

    # Initializes a module with the given environment hash.
    #
    # @param env [Hash] environment hash
    # @return [void]
    def initialize(env)
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

    # Returns true if the module is a collection module. See also
    # #collection_module!
    #
    # @return [bool]
    def collection_module?
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

    # Normalize an import reference, turning a relative path into an absolute one.
    #
    # @param ref [String] input ref
    # @return [String] normalized ref
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
      raise 'No template block/proc given' if !proc

      Papercraft::Template.new(proc)
    end

    # Creates and returns a Papercraft XML template created with the given block.
    #
    # @param proc [Proc, nil] template proc or nil
    # @param block [Proc] template block
    # @return [Papercraft::Template] template
    def template_xml(proc = nil, &block)
      proc ||= block
      raise 'No template block/proc given' if !proc

      Papercraft::Template.new(proc, mode: :xml)
    rescue StandardError => e
      p e
      p e.backtrace
      raise
    end

    # Creates and returns a Syntropy app for the given environment. The app's
    # environment is based on the module's env merged with the given parameters.
    #
    # @param env [Hash] environment
    # @return [Syntropy::App]
    def app(**env)
      env = @env.merge(env)
      Syntropy::App.new(**env)
    end

    def handle_syntax_error(env, e)
      $stderr.puts("\n#{e.message}") if !Syntropy.test_mode
      m = e.message.match(/^(.+): syntax/)
      raise e if !m

      location = m[1]
      e2 = SyntaxError.new("Syntax errors found in module #{env[:ref]}")
      e2.set_backtrace([location] + e.backtrace)
      raise e2
    end
  end
end
