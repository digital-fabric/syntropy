# frozen_string_literal: true

require 'yaml'
require 'securerandom'

module Syntropy
  # Markdown parsing.
  module Markdown
    FRONT_MATTER_REGEXP = /\A(---\s*\n.*?\n?)^((---|\.\.\.)\s*$\n?)/m
    YAML_OPTS = {
      permitted_classes: [Date],
      symbolize_names: true
    }.freeze

    class Controller
      def initialize(env, atts, md)
        @env = env
        @atts = atts
        @md = md
        @module_loader = env[:module_loader]
      end

      def to_proc
        ->(req) {
          case req.method
          when 'head'
            req.respond_html(nil)
          when 'get'
            md = process_md_embeds
            html = render(md)
            req.respond_html(html)
          else
            req.respond(nil, ':status' => HTTP::METHOD_NOT_ALLOWED)
          end
        }
      end

      private

      def process_md_embeds
        return @md if @embedded_templates&.empty?

        @embedded_templates = {}
        @md.gsub(/^```ruby\n# render: true\n(.*?)\r?\n```\n/m) {
          snippet = Regexp.last_match[1]
          templ = @embedded_templates[snippet] ||= prepare_snippet_template(snippet)
          Papercraft.html(templ)
        }
      end

      def prepare_snippet_template(snippet, location = nil)
        fn = "/tmp/snippet-#{SecureRandom.hex(8)}.rb"
        src = "->() do\n#{snippet}\nend"
        IO.write(fn, src)
        instance_eval src, fn
      end

      def render(md)
        @template ||= make_template
        Papercraft.html(@template, md: md, **@atts)
      end

      def make_template
        layout = make_layout
        Papercraft.apply(layout) { |md:, **| markdown(md) }
      end

      def make_layout
        return default_layout if !@atts[:layout]
        raise Error, 'Missing module loader' if !@module_loader

        @module_loader.load("_layout/#{@atts[:layout]}")
      end

      def default_layout
        ->(**atts) {
          html5 {
            head {
              title atts[:title] if atts[:title]
            }
            body {
              render_children(**atts)
              auto_refresh!
            }
          }
        }
      end
    end

    class << self
      # Parses the markdown file at the given path.
      #
      # @param path [String] file path
      # @return [Array] an tuple containing properties<Hash>, contents<String>
      def parse_file(path, env)
        md = IO.read(path) || ''
        atts = {}
        atts[:url] = path_to_url(path, env[:app_root]) if env[:app_root]
        parse_date(atts, path)

        parse_md(atts, md)
      end

      def parse_md(atts, md)
        html = parse_content(atts, md)
        [atts, html]
      end

      def make_controller(env, atts, md)
        Controller.new(env, atts, md).to_proc
        # layout = setup_layout_template(env, atts)
        
        # ->(req) {
        #   case req.method
        #   when 'head'
        #     req.respond_html(nil)
        #   when 'get'
        #     html = render_md(env, atts, md)
        #     req.respond_html(html)
        #   else
        #     req.respond(nil, ':status' => HTTP::METHOD_NOT_ALLOWED)
        #   end
        # }
      end

      private

      # Parses date information from the given path.
      #
      # @param atts [Hash] file attributes
      # @param path [String] file path
      # @return [void]
      def parse_date(atts, path)
        # Parse date from file name
        if (m = path.match(/(\d{4}-\d{2}-\d{2})/))
          atts[:date] ||= Date.parse(m[1])
        end
      end

      # Parses the markdown content and front matter attributes from the given content.
      #
      # @param atts [Hash] file attributes
      # @param content [String] file content
      # @return [String] parsed markdown content
      def parse_content(atts, content)
        if (m = content.match(FRONT_MATTER_REGEXP))
          front_matter = m[1]
          content = m.post_match

          yaml = YAML.safe_load(front_matter, **YAML_OPTS)
          atts.merge!(yaml)
        end
        content
      end

      # Converts the markdown file path to URL
      #
      # @param path [String] file path
      # @param app_root [String] app root directory
      # @return [String] url
      def path_to_url(path, app_root)
        if app_root == '/'
          path.gsub(/\.md$/, '')
        else
          path.gsub(/#{app_root}/, '').gsub(/\.md$/, '')
        end
      end

      def render_md(env, atts, md)
        
      end
    end
  end
end
