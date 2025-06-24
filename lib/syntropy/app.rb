# frozen_string_literal: true

require 'qeweney'
require 'json'
require 'papercraft'

require 'syntropy/errors'
require 'syntropy/file_watch'
require 'syntropy/module'

module Syntropy
  class App
    attr_reader :route_cache

    def initialize(machine, src_path, mount_path, env = {})
      @machine = machine
      @src_path = src_path
      @mount_path = mount_path
      @route_cache = {}
      @env = env

      @relative_path_re = calculate_relative_path_re(mount_path)
      if (wf = env[:watch_files])
        period = wf.is_a?(Numeric) ? wf : 0.1
        machine.spin do
          Syntropy.file_watch(@machine, src_path, period: period) { invalidate_cache(it) }
        rescue Exception => e
          p e
          p e.backtrace
        end
      end
    end

    def find_route(path, cache: true)
      cached = @route_cache[path]
      return cached if cached

      entry = calculate_route(path)
      if entry[:kind] != :not_found
        @route_cache[path] = entry if cache
      end
      entry
    end

    def invalidate_cache(fn)
      invalidated_keys = []
      @route_cache.each do |k, v|
        invalidated_keys << k if v[:fn] == fn
      end

      invalidated_keys.each { @route_cache.delete(it) }
    end

    def call(req)
      entry = find_route(req.path)
      render_entry(req, entry)
    rescue StandardError => e
      p e
      p e.backtrace
      req.respond(e.message, ':status' => Qeweney::Status::INTERNAL_SERVER_ERROR)
    end

    private

    def calculate_relative_path_re(mount_path)
      mount_path = '' if mount_path == '/'
      /^#{mount_path}(?:\/(.*))?$/
    end

    FILE_KINDS = {
      '.rb' => :module,
      '.md' => :markdown
    }
    NOT_FOUND = { kind: :not_found }

    # We don't allow access to path with /.., or entries that start with _
    FORBIDDEN_RE = /(\/_)|((\/\.\.)\/?)/

    def calculate_route(path)
      return NOT_FOUND if path =~ FORBIDDEN_RE

      m = path.match(@relative_path_re)
      return NOT_FOUND if !m

      relative_path = m[1] || ''
      fs_path = File.join(@src_path, relative_path)

      return file_entry(fs_path) if File.file?(fs_path)
      return find_index_entry(fs_path) if File.directory?(fs_path)

      entry = find_file_entry_with_extension(fs_path)
      return entry if entry[:kind] != :not_found

      find_up_tree_module(path)
    end

    def file_entry(fn)
      { fn: fn, kind: FILE_KINDS[File.extname(fn)] || :static }
    end

    def find_index_entry(dir)
      find_file_entry_with_extension(File.join(dir, 'index'))
    end

    def find_file_entry_with_extension(path)
      fn = "#{path}.html"
      return file_entry(fn) if File.file?(fn)

      fn = "#{path}.md"
      return file_entry(fn) if File.file?(fn)

      fn = "#{path}.rb"
      return file_entry(fn) if File.file?(fn)

      fn = "#{path}+.rb"
      return file_entry(fn) if File.file?(fn)

      NOT_FOUND
    end

    def find_up_tree_module(path)
      parent = parent_path(path)
      return NOT_FOUND if !parent

      entry = find_route("#{parent}+.rb", cache: false)
      entry[:kind] == :module ? entry : NOT_FOUND
    end

    UP_TREE_PATH_RE = /^(.+)?\/[^\/]+$/

    def parent_path(path)
      m = path.match(UP_TREE_PATH_RE)
      m && m[1]
    end

    def render_entry(req, entry)
      case entry[:kind]
      when :not_found
        req.respond('Not found', ':status' => Qeweney::Status::NOT_FOUND)
      when :static
        entry[:mime_type] ||= Qeweney::MimeTypes[File.extname(entry[:fn])]
        req.respond(IO.read(entry[:fn]), 'Content-Type' => entry[:mime_type])
      when :markdown
        body = render_markdown(IO.read(entry[:fn]))
        req.respond(body, 'Content-Type' => 'text/html')
      when :module
        call_module(entry, req)
      else
        raise "Invalid entry kind"
      end
    end

    def call_module(entry, req)
      entry[:code] ||= load_module(entry)
      if entry[:code] == :invalid
        req.respond(nil, ':status' => Qeweney::Status::INTERNAL_SERVER_ERROR)
        return
      end

      entry[:code].call(req)
    rescue StandardError => e
      p e
      p e.backtrace
      req.respond(nil, ':status' => Qeweney::Status::INTERNAL_SERVER_ERROR)
    end

    def load_module(entry)
      loader = Syntropy::ModuleLoader.new(@src_path, @env)
      ref = entry[:fn].gsub(%r{^#{@src_path}\/}, '').gsub(/\.rb$/, '')
      o = loader.load(ref)
      # klass = Class.new
      # o = klass.instance_eval(body, entry[:fn], 1)

      if o.is_a?(Papercraft::HTML)
        return wrap_template(o)
      else
        return o
      end
    end

    def wrap_template(templ)
      ->(req) {
        body = templ.render
        req.respond(body, 'Content-Type' => 'text/html')
      }
    end

    def render_markdown(str)
      Papercraft.markdown(str)
    end
  end
end
