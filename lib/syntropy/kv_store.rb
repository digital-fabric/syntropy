# frozen_string_literal: true

module Syntropy
  # The KVStore class implements an SQLite-backed key-value store
  class KVStore
    attr_reader :table_name

    def initialize(db, table_name)
      @table_name = table_name
      setup_queries
      apply_schema(db)
    end

    def get(db, key)
      db.query_single_splat(@sql_get, key)
    end

    def set(db, key, value)
      db.execute(@sql_set, key, value)
    end

    def setex(db, key, value, ttl)
      db.execute(@sql_setex, key, value, ttl ? Time.now.to_f + ttl : nil)
    end

    def sweep(db)
      db.execute(@sql_sweep, Time.now.to_f)
    end

    private

    def apply_schema(db)
      db.execute <<~SQL
        create table if not exists #{@table_name} (key text primary key, value, expires float);
        create index if not exists idx_#{@table_name}_expires on #{@table_name} (expires) where expires is not null;
      SQL
    end

    def setup_queries
      @sql_get = "select value from #{@table_name} where key = ?"

      @sql_set = <<~SQL
        insert into #{@table_name} (key, value)
        values($1, $2)
        on conflict (key) do update set value = $2, expires = null
      SQL

      @sql_setex = <<~SQL
        insert into #{@table_name} (key, value, expires)
        values($1, $2, $3)
        on conflict (key) do update set value = $2, expires = $3
      SQL

      @sql_sweep = "delete from #{@table_name} where expires < ?"
    end
  end
end
