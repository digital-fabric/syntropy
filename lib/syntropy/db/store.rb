# frozen_string_literal: true

module Syntropy
  module DB
    class Store
      def initialize(connection_pool)
        @connection_pool = connection_pool
      end

      def query(sql, *, **)
        @connection_pool.with_db { it.query(sql, *, **) }
      end

      def query_single_row(sql, *, **)
        @connection_pool.with_db { it.query_single(sql, *, **) }
      end

      def query_single_value(sql, *, **)
        @connection_pool.with_db { it.query_single_splat(sql, *, **) }
      end

      def execute(sql, *, **)
        @connection_pool.with_db { it.execute(sql, *, **) }
      end

      def transaction(&)
        @connection_pool.with_db(&)
      end
    end
  end
end
