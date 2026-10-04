# frozen_string_literal: true

require 'yaml'
require 'json'
require 'syntropy/markdown'

module Syntropy
  # A collection represents a collection of data entities represented in files.
  class Collection
    attr_reader :root, :url_base

    # Initializes a collection.
    #
    # @param machine [UringMachine]
    # @param root [String] collection root
    # @param url_base [String] URL base
    # @return [void]
    def initialize(machine:, root:, url_base:)
      @machine = machine
      @root = File.expand_path(root)
      @url_base = url_base
      @items = {}

      calc_collection_tree
    end

    # Returns a list of items in the collection.
    #
    # @return [Array] items
    def list
      @items.values
    end

    # Returns the item corresponding to the given URL.
    #
    # @param url [String] URL
    # @return [Hash] item
    def get(url)
      @items[url]
    end

    private

    # Calculates the collection tree.
    #
    # @return [void]
    def calc_collection_tree
      queue = UM::Queue.new
      Dir[File.join(@root, '**')].each do |fn|
        ref = fn_to_ref(fn)
        url = File.join(@url_base, ref)
        item = {
          fn:,
          ref:,
          url:,
          type: :markdown
        }
        @items[url] = item
        @machine.push(queue, item)
      end
      4.times { @machine.push(queue, :stop) }

      fibers = 4.times.map {
        @machine.spin {
          loop {
            item = @machine.shift(queue)
            break if item == :stop

            load_item(item)
          }
        }
      }
      @machine.join(fibers)
    end

    # Converts a filename to a ref.
    #
    # @param fn [String]
    # @return [String] ref
    def fn_to_ref(fn)
      @ref_regexp ||= /^#{@root}\/(.+)\.(?:md|json)$/
      fn.match(@ref_regexp)[1]
    end

    # Loads the given item.
    #
    # @param item [Hash]
    # @return [void]
    def load_item(item)
      basename = File.basename(item[:fn])
      case (ext = File.extname(basename))
      when '.md'
        load_item_markdown(item)
      when '.json'
        load_item_json(item)
      when '.yml', '.yaml'
        load_item_yaml(item)
      else
        raise Syntropy::Error, "Unkown file type #{ext}"
      end
    end

    # Loads ands parses the file for the given markdown item.
    #
    # @param item [Hash]
    # @return [void]
    def load_item_markdown(item)
      attributes, body = Markdown.parse_file(item[:fn], {})
      item.merge!(attributes:, body:)
    end

    # Loads ands parses the file for the given JSON item.
    #
    # @param item [Hash]
    # @return [void]
    def load_item_json(item)
      data = @machine.file_read(item[:fn])
      item[:data] = JSON.parse(data, symbolize_names: true)
    end

    YAML_OPTS = {
      permitted_classes: [Date],
      symbolize_names: true
    }.freeze

    # Loads ands parses the file for the given YAML item.
    #
    # @param item [Hash]
    # @return [void]
    def load_item_yaml(item)
      data = @machine.file_read(item[:fn])
      item[:data] = YAML.safe_load(data, **YAML_OPTS)
    end
  end
end
