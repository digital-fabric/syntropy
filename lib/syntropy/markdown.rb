# frozen_string_literal: true

require 'yaml'

module Syntropy
  # Markdown parsing.
  module Markdown
    FRONT_MATTER_REGEXP = /\A(---\s*\n.*?\n?)^((---|\.\.\.)\s*$\n?)/m
    YAML_OPTS = {
      permitted_classes: [Date],
      symbolize_names: true
    }.freeze

    class << self
      # Parses the markdown file at the given path.
      #
      # @param path [String] file path
      # @return [Array] an tuple containing properties<Hash>, contents<String>
      def parse(path, env)
        content = IO.read(path) || ''
        atts = {}

        parse_date(path, atts)
        content = parse_content(content, atts)
        atts[:url] = path_to_url(path, env[:root_dir]) if env[:root_dir]

        [atts, content]
      end

      private

      # Parses date information from the given path.
      #
      # @param path [String] file path
      # @param atts [Hash] file attributes
      # @return [void]
      def parse_date(path, atts)
        # Parse date from file name
        if (m = path.match(/(\d{4}-\d{2}-\d{2})/))
          atts[:date] ||= Date.parse(m[1])
        end
      end

      # Parses the markdown content and front matter attributes from the given content.
      #
      # @param content [String] file content
      # @param atts [Hash] file attributes
      # @return [String] parsed markdown content
      def parse_content(content, atts)
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
      # @param root_dir [String] app root directory
      # @return [String] url
      def path_to_url(path, root_dir)
        path.gsub(/#{root_dir}/, '').gsub(/\.md$/, '')
      end
    end
  end
end
