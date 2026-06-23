export self

def connection_pool
  @connection_pool ||= Storage::ConnectionPool.new(@machine, @env[:config][:storage][:path], 4)
end

def schema
  Storage::Schema.new(module_loader: @module_loader, schema_root: '_schema')
end

def migrate!
  schema.apply(connection_pool)
end
