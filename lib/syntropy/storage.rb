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
end
