# frozen_string_literal: true

require 'extralite'
require 'syntropy/storage/connection_pool'
require 'syntropy/storage/schema'

module Syntropy
  # Extensions to the Extralite::Database class
  module DatabaseExtensions
    # Returns the stored value for the given key. This method is used to
    # retrieve previously stored prepared queries.
    #
    # @param key [any] query key
    # @return [Extralite::Query, nil] query
    def [](key)
      (@query_map ||= {})[key]
    end

    # Sets the query value for the given key. This method is used to
    # store prepared queries for the database.
    #
    # @param key [any] query key
    # @param value [Extralite::Query] query
    # @return [Extralite::Query] query
    def []=(key, value)
      (@query_map ||= {})[key] = value
    end
  end

  Extralite::Database.include(DatabaseExtensions)

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
  end
end
