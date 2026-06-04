# frozen_string_literal: true

require 'syntropy/db/store'

module Syntropy
  module DB
    # The KVStore class implements an SQLite-backed key-value store
    class KVStore < Store
      attr_reader :q_get, :q_set

      def self.apply_schema(db, table_name)
        db.execute <<~SQL
          create table if not exists #{table_name} (key text primary key, value, expires float);
          create index if not exists idx_#{table_name}_expires on #{table_name} (expires) where expires is not null;
        SQL
      end

      def initialize(connection_pool, table_name)
        super(connection_pool)
        @table_name = table_name

        setup_queries
      end

      def get(db, key)
        db[@q_get].bind(key).next
      end

      def set(db, key, value)
        db[@q_set].execute(key, value)
      end

      def setex(db, key, value, ttl)
        db[@q_setex].execute(key, value, ttl ? Time.now.to_f + ttl : nil)
      end

      def sweep(db)
        db[@q_sweep].execute(Time.now.to_f)
      end

      private

      def setup_queries
        @q_get = Syntropy::DB.prepare_splat <<~SQL
          select value from #{@table_name}
          where key = ?
        SQL

        @q_set = Syntropy::DB.prepare <<~SQL
          insert into #{@table_name} (key, value)
          values($1, $2)
          on conflict (key) do update set value = $2, expires = null
        SQL

        @q_setex = Syntropy::DB.prepare <<~SQL
          insert into #{@table_name} (key, value, expires)
          values($1, $2, $3)
          on conflict (key) do update set value = $2, expires = $3
        SQL

        @q_sweep = Syntropy::DB.prepare <<~SQL
          delete from #{@table_name}
          where expires < ?
        SQL
      end
    end
  end
end
