# frozen_string_literal: true

require 'json'
require 'yaml'

require 'qeweney'
require 'papercraft'

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

    def initialize(machine, src_path, mount_path, opts = {})
      @machine = machine
      @src_path = File.expand_path(src_path)
      @mount_path = mount_path
      @opts = opts

      @module_loader = Syntropy::ModuleLoader.new(@src_path, @opts)
      @router = Syntropy::Router.new(@opts, @module_loader)

      @machine.spin do
        # we do startup stuff asynchronously, in order to first let TP2 do its
        # setup tasks
        @machine.sleep 0.15
        @opts[:logger]&.call("Serving from #{File.expand_path(@src_path)}")
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
      case entry[:kind]
      when :not_found
        respond_not_found(req, entry)
      when :static
        respond_static(req, entry)
      when :markdown
        respond_markdown(req, entry)
      when :module
        respond_module(req, entry)
      else
        raise 'Invalid entry kind'
      end
    end

    def respond_not_found(req, _entry)
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
        'get'   => -> { [render_markdown(entry[:fn]), headers] }
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
      ref = entry[:fn].gsub(%r{^#{@src_path}/}, '').gsub(/\.rb$/, '')
      o = @module_loader.load(ref)
      o.is_a?(Papercraft::Template) ? wrap_template(o) : o
    rescue Exception => e
      @opts[:logger]&.call("Error while loading module #{ref}: #{e.message}")
      :invalid
    end

    def wrap_template(templ)
      lambda { |req|
        body = templ.render
        req.respond(body, 'Content-Type' => 'text/html')
      }
    end

    def render_markdown(fn)
      atts, md = parse_markdown_file(fn)

      if atts[:layout]
        layout = @module_loader.load("_layout/#{atts[:layout]}")
        html = layout.apply { emit_markdown(md) }.render
      else
        html = Papercraft.markdown(md)
      end
      html
    end

    DATE_REGEXP = /(\d{4}\-\d{2}\-\d{2})/
    FRONT_MATTER_REGEXP = /\A(---\s*\n.*?\n?)^((---|\.\.\.)\s*$\n?)/m
    YAML_OPTS = {
      permitted_classes: [Date],
      symbolize_names: true
    }

    # Parses the markdown file at the given path.
    #
    # @param path [String] file path
    # @return [Array] an tuple containing properties<Hash>, contents<String>
    def parse_markdown_file(path)
      content = IO.read(path) || ''
      atts = {}

      # Parse date from file name
      if (m = path.match(DATE_REGEXP))
        atts[:date] ||= Date.parse(m[1])
      end

      if (m = content.match(FRONT_MATTER_REGEXP))
        front_matter = m[1]
        content = m.post_match

        yaml = YAML.safe_load(front_matter, **YAML_OPTS)
        atts = atts.merge(yaml)
      end

      [atts, content]
    end
  end
end
