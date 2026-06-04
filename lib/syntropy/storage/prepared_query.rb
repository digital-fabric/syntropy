# frozen_string_literal: true

require 'extralite'

module Syntropy
  module Storage
    class << self
      def prepare(sql)
        PreparedQuery.new(sql)
      end

      def prepare_splat(sql)
        PreparedQuery.new(sql, :prepare_splat)
      end
    end

    # Represents information about a prepared query
    class PreparedQuery
      attr_reader :sql, :mode

      def initialize(sql, mode = :prepare)
        @sql = sql
        @mode = mode
      end
    end

    # Extensions for Extralite::Database
    module ExtraliteDatabaseExtensions
      def [](pq)
        (@prepared_queries ||= {})[pq] ||= send(pq.mode, pq.sql)
      end
    end

    ::Extralite::Database.include(ExtraliteDatabaseExtensions)
  end
end
