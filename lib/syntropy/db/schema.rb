# frozen_string_literal: true

module Syntropy
  module DB
    class Schema
      def initialize(&)
        @migrations = {
        }
        run_schema_block(&)
      end

      def apply(connection_pool)
        execute_migrations(connection_pool)
      end

      def current_version(connection_pool)
        connection_pool.with_db do |db|
          get_schema_version(db)
        end
      end

      private

      class SchemaBlockRunner
        def initialize(migrations, &)
          @migrations = migrations
          instance_eval(&)
        end

        def execute(sql, *, **)
          (@migrations['0000'] ||= []) << proc { execute(sql, *, **) }
        end

        def initial(&block)
          (@migrations['0000'] ||= []) << block
        end

        def version(key, &block)
          (@migrations[key] ||= []) << block
        end
      end

      def run_schema_block(&)
        SchemaBlockRunner.new(@migrations, &)
      end

      def execute_migrations(connection_pool)
        connection_pool.with_db do |db|
          current_version = get_schema_version(db)
          migrations_keys = @migrations.keys.sort
          migrations_keys.select { it > current_version } if current_version

          migrations_keys.each do |key|
            db.transaction do
              @migrations[key].each { db.instance_eval(&it) }
              set_schema_version(db, key)
              current_version = key
            end
          end

          current_version
        end
      end

      def get_schema_version(db)
        db.execute <<~SQL
          create table if not exists __syntropy_schema__(
            k text primary key,
            v text
          );
        SQL
        db.query_single_splat <<~SQL
          select v from __syntropy_schema__
          where k = 'version'
        SQL
      end

      def set_schema_version(db, version)
        db.execute <<~SQL, v: version
          insert into __syntropy_schema__ (k, v)
          values ('version', :v)
          on conflict(k) do update set v = :v
        SQL
      end
    end
  end
end
