# frozen_string_literal: true

require 'json'
require 'yaml'

require 'qeweney'
require 'p2'

require 'syntropy/errors'
require 'syntropy/file_watch'
require 'syntropy/module'

module Syntropy
  class App
    class << self
      def load(opts)
        site_file_app(opts) || default_app(opts)
      end

      private

      def site_file_app(opts)
        site_fn = File.join(opts[:location], '_site.rb')
        return nil if !File.file?(site_fn)

        loader = Syntropy::ModuleLoader.new(opts[:location], opts)
        loader.load('_site')
      end

      def default_app(opts)
        new(opts[:machine], opts[:location], opts[:mount_path] || '/', opts)
      end
    end

    def initialize(machine, location, mount_path, opts = {})
      @machine = machine
      @location = File.expand_path(location)
      @mount_path = mount_path
      @opts = opts

      @module_loader = Syntropy::ModuleLoader.new(@location, @opts)
      @router = Syntropy::Router.new(@opts, @module_loader)

      @machine.spin do
        # we do startup stuff asynchronously, in order to first let TP2 do its
        # setup tasks
        @machine.sleep 0.15
        @opts[:logger]&.info(
          message: "Serving from #{File.expand_path(@location)}"
        )
        @router.start_file_watcher if opts[:watch_files]
      end
    end

    def call(req)
      entry = @router[req.path]
      render_entry(req, entry)
    rescue Syntropy::Error => e
      msg = e.message
      req.respond(msg.empty? ? nil : msg, ':status' => e.http_status)
    rescue StandardError => e
      p e
      p e.backtrace
      req.respond(e.message, ':status' => Qeweney::Status::INTERNAL_SERVER_ERROR)
    end

    private

    def render_entry(req, entry)
      kind = entry[:kind]
      return respond_not_found(req) if kind == :not_found

      entry[:proc] ||= calculate_route_proc(entry)
      entry[:proc].(req)
    end

    def calculate_route_proc(entry)
      render_proc = route_render_proc(entry)
      @router.calc_route_proc_with_hooks(entry, render_proc)
    end

    def route_render_proc(entry)
      case entry[:kind]
      when :static
        ->(req) { respond_static(req, entry) }
      when :markdown
        ->(req) { respond_markdown(req, entry) }
      when :module
        load_module(entry)
      else
        raise 'Invalid entry kind'
      end
    end

    def respond_not_found(req)
      headers = { ':status' => Qeweney::Status::NOT_FOUND }
      case req.method
      when 'head'
        req.respond(nil, headers)
      else
        req.respond('Not found', headers)
      end
    end

    def respond_static(req, entry)
      entry[:mime_type] ||= Qeweney::MimeTypes[File.extname(entry[:fn])]
      headers = { 'Content-Type' => entry[:mime_type] }
      req.respond_by_http_method(
        'head'  => [nil, headers],
        'get'   => -> { [IO.read(entry[:fn]), headers] }
      )
    end

    def respond_markdown(req, entry)
      entry[:mime_type] ||= Qeweney::MimeTypes[File.extname(entry[:fn])]
      headers = { 'Content-Type' => entry[:mime_type] }
      req.respond_by_http_method(
        'head'  => [nil, headers],
        'get'   => -> { [render_markdown(entry), headers] }
      )
    end

    def respond_module(req, entry)
      entry[:proc] ||= load_module(entry)
      if entry[:proc] == :invalid
        req.respond(nil, ':status' => Qeweney::Status::INTERNAL_SERVER_ERROR)
        return
      end

      entry[:proc].call(req)
    rescue Syntropy::Error => e
      req.respond(nil, ':status' => e.http_status)
    rescue StandardError => e
      p e
      p e.backtrace
      req.respond(nil, ':status' => Qeweney::Status::INTERNAL_SERVER_ERROR)
    end

    def load_module(entry)
      ref = entry[:fn].gsub(%r{^#{@location}/}, '').gsub(/\.rb$/, '')
      o = @module_loader.load(ref)
      wrap_module(o)
    rescue Exception => e
      @opts[:logger]&.error(
        message:  "Error while loading module #{ref}",
        error:    e
      )
      :invalid
    end

    def wrap_module(mod)
      case mod
      when P2::Template
        wrap_p2_template(mod)
      when Papercraft::Template
        wrap_papercraft_template(mod)
      else
        mod
      end
    end

    def wrap_p2_template(wrapper)
      template = wrapper.proc
      lambda { |req|
        headers = { 'Content-Type' => 'text/html' }
        req.respond_by_http_method(
          'head'  => [nil, headers],
          'get'   => -> { [template.render, headers] }
        )
      }
    end

    def wrap_papercraft_template(template)
      lambda { |req|
        headers = { 'Content-Type' => template.mime_type }
        req.respond_by_http_method(
          'head'  => [nil, headers],
          'get'   => -> { [template.render, headers] }
        )
      }
      
    end

    def render_markdown(entry)
      atts, md = Syntropy.parse_markdown_file(entry[:fn], @opts)

      if (layout = atts[:layout])
        entry[:applied_layouts] ||= {}
        proc = entry[:applied_layouts][layout] ||= markdown_layout_proc(layout)
        html = proc.render(md: md, **atts)
      else
        html = P2.markdown(md)
      end
      html
    end

    def markdown_layout_proc(layout)
      layout = @module_loader.load("_layout/#{layout}")
      layout.apply { |md:, **|
        markdown(md)
      }
    end
  end
end
