# frozen_string_literal: true

module Syntropy
  module Storage
    class Schema
      def initialize(module_loader: nil, schema_root: '_schema', &)
        @migrations = {}
        @module_loader = module_loader
        @schema_root = schema_root
        load_schema_from_modules if @module_loader
        run_schema_block(&) if block_given?
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

      def load_schema_from_modules
        modules = @module_loader.list(@schema_root)
        modules.each do |name|
          @migrations[File.basename(name)] = @module_loader.load(name)
        end
      end

      class SchemaBlockRunner
        def initialize(migrations, &)
          @migrations = migrations
          instance_eval(&)
        end

        def initial(&block)
          @migrations['0000'] = block
        end

        def version(key, &block)
          @migrations[key] = block
        end
      end

      def run_schema_block(&)
        SchemaBlockRunner.new(@migrations, &)
      end

      def execute_migrations(connection_pool)
        connection_pool.with_db do |db|
          current_version = get_schema_version(db)
          migrations_keys = @migrations.keys.sort
          migrations_keys.select! { it > current_version } if current_version

          migrations_keys.each do |key|
            db.transaction do
              @migrations[key].(db)
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
        db.execute <<~SQL, version
          insert into __syntropy_schema__ (k, v)
          values ('version', $1)
          on conflict(k) do update set v = $1
        SQL
      end
    end
  end
end
