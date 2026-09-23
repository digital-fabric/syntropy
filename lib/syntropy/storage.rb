# frozen_string_literal: true

require 'extralite'
require 'syntropy/connection_pool'
require 'syntropy/schema'
require 'syntropy/kv_store'

module Syntropy
  class Storage
    attr_reader :connection_pool, :schema
    
    def initialize(machine, module_loader, config)
      @machine = machine
      @module_loader = module_loader
      @config = config

      raise Syntropy::Error, 'Missing storage config' if !config
      raise Syntropy::Error, 'Missing storage config' if !config[:path]

      @connection_pool ||= ConnectionPool.new(
        @machine,
        config[:path],
        config[:concurrency] || 4
      )

      @schema = Schema.new(
        module_loader: @module_loader,
        schema_root: @config[:schema_root] || '_schema'
      )
    end

    def query(*, **, &)
      connection_pool.with_db { it.query(*, **, &) }
    end

    def query_single_value(*, **, &)
      connection_pool.with_db { it.query_splat(*, **, &) }
    end

    def execute(*, **)
      connection_pool.with_db { it.execute(*, **) }
    end
  end
end
