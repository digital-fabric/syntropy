# frozen_string_literal: true

require 'syntropy/markdown'

module Syntropy
  class Collection
    attr_reader :root, :url_base

    def initialize(machine:, root:, url_base:)
      @machine = machine
      @root = File.expand_path(root)
      @url_base = url_base
      @items = {}

      calc_collection_tree
    end

    def list
      @items.values
    end

    def get(url)
      @items[url]
    end

    private

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

    def fn_to_ref(fn)
      @ref_regexp ||= /^#{@root}\/(.+)\.(?:md|json)$/
      fn.match(@ref_regexp)[1]
    end

    def load_item(item)
      basename = File.basename(item[:fn])
      data = @machine.file_read(item[:fn])
      case File.extname(basename)
      when '.md'
        load_item_markdown(item, data)
      when '.json'
        load_item_json(item, data)
      end
    end

    def load_item_markdown(item, data)
      attributes, body = Markdown.parse_file(item[:fn], {})
      item.merge!(attributes:, body:)
    end

    def load_item_json(item)
    end
  end
end
