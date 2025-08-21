# frozen_string_literal: true

require 'yaml'

module Syntropy
  DATE_REGEXP = /(\d{4}-\d{2}-\d{2})/
  FRONT_MATTER_REGEXP = /\A(---\s*\n.*?\n?)^((---|\.\.\.)\s*$\n?)/m
  YAML_OPTS = {
    permitted_classes: [Date],
    symbolize_names: true
  }

  # Parses the markdown file at the given path.
  #
  # @param path [String] file path
  # @return [Array] an tuple containing properties<Hash>, contents<String>
  def self.parse_markdown_file(path, opts)
    content = IO.read(path) || ''
    atts = {}

    # Parse date from file name
    m = path.match(DATE_REGEXP)
    atts[:date] ||= Date.parse(m[1]) if m

    if (m = content.match(FRONT_MATTER_REGEXP))
      front_matter = m[1]
      content = m.post_match

      yaml = YAML.safe_load(front_matter, **YAML_OPTS)
      atts = atts.merge(yaml)
    end

    if opts[:location]
      atts[:url] = path
                   .gsub(/#{opts[:location]}/, '')
                   .gsub(/\.md$/, '')
    end

    [atts, content]
  end
end
