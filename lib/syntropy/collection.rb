# frozen_string_literal: true

require 'yaml'
require 'json'
require 'syntropy/markdown'

module Syntropy
  # A collection represents a collection of data entities represented in files.
  class Collection
    attr_reader :root, :root_dir, :url_base

    # Initializes a collection.
    #
    # @param machine [UringMachine]
    # @param root [String] collection root
    # @param url_base [String] URL base
    # @return [void]
    def initialize(machine:, root:, url_base:)
      @machine = machine
      @root_dir = File.expand_path(root)
      @url_base = url_base
      @list = {} # list of non-directory items
      @root = make_tree_root
      @dirs = { @root_dir => @root } # mapping directory paths to tree items

      calc_collection_tree
    end

    # Returns a list of items in the collection.
    #
    # @return [Array] items
    def list
      @list.values
    end

    # Returns the item corresponding to the given URL.
    #
    # @param url [String] URL
    # @return [Hash] item
    def get(url)
      @list[url]
    end

    private

    def make_tree_root
      {
        fn: find_directory_data_file(@root_dir),
        ref: '',
        url: url_base,
        type: :directory,
        items: []
      }
    end

    # Calculates the collection tree.
    #
    # @return [void]
    def calc_collection_tree
      queue = UM::Queue.new
      Dir[File.join(@root_dir, '**/*')].each do |fn|
        next if File.basename(fn) =~ /^_/

        ref = fn_to_ref(fn)
        url = File.join(@url_base, ref)
        parent_fn = File.expand_path(File.join(fn, '..'))
        parent = @dirs[parent_fn]
        raise Error, "Parent not found: #{parent_fn}" if !parent

        if File.directory?(fn)
          dir = {
            fn: find_directory_data_file(fn),
            ref:,
            url:,
            type: :directory,
            items: []
          }
          @dirs[fn] = dir
          parent[:items] << dir
          @machine.push(queue, dir) if dir[:fn]
        else
          item = {
            fn:,
            ref:,
            url:
          }
          @list[url] = item
          parent[:items] << item
          @machine.push(queue, item)
        end
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

      add_prev_next_links
    end

    def scan_files(path, queue)
    end

    # Converts a filename to a ref.
    #
    # @param fn [String]
    # @return [String] ref
    def fn_to_ref(fn)
      @ref_rel_regexp ||= /^#{@root_dir}\/(.+)/
      rel = fn.match(@ref_rel_regexp)[1]

      (m = rel.match(/^(.+)\.(md|json|yml|yaml)$/)) ? m[1] : rel
    end

    # Returns the data file for the given directory.
    #
    # @param dir [String]
    # @return [String, nil] directory data file
    def find_directory_data_file(dir)
      (
        detect_file(File.join(dir, '_index.yml')) ||
        detect_file(File.join(dir, '_index.json'))
      )
    end

    # Detects if the given file exists.
    #
    # @param fn [String]
    # @return [String, nil] filename if exists, nil otherwise
    def detect_file(fn)
      File.file?(fn) ? fn : nil
    end

    # Loads the given item.
    #
    # @param item [Hash]
    # @return [void]
    def load_item(item)
      basename = File.basename(item[:fn])
      case (ext = File.extname(basename))
      when '.md'
        item[:type] ||= :markdown
        load_item_markdown(item)
      when '.json'
        item[:type] ||= :json
        load_item_json(item)
      when '.yml', '.yaml'
        item[:type] ||= :yaml
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

    def add_prev_next_links
      last = nil
      @list.each_value { |item|
        if last
          item[:prev] = last
          last[:next] = item
        end
        last = item
      }
    end
  end
end
