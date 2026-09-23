# frozen_string_literal: true

require_relative 'helper'
require 'securerandom'

class StorageTest < Minitest::Test
  def setup
    @machine = UM.new
    @fn = "/tmp/#{SecureRandom.hex(8)}.db"

    @module_loader = Syntropy::ModuleLoader.new({
      machine:  @machine,
      app_root: File.join(__dir__, 'fixtures/schema')
    })
  end

  def test_storage_missing_config
    config = {}
    assert_raises(Syntropy::Error) {
      Syntropy::Storage.new(
        @machine,
        @module_loader,
        config
      )
    }
  end

  def test_storage_connection_pool
    config = {
      path:  @fn
    }

    storage = Syntropy::Storage.new(
      @machine,
      @module_loader,
      config
    )

    cp = storage.connection_pool
    assert_kind_of Syntropy::ConnectionPool, cp

    db = Extralite::Database.new(@fn)

    cp.with_db {
      it.execute('create table x (y); insert into x (y) values (42);')
    }

    assert_equal 42, db.query_single_splat('select y from x')
  end

  def test_storage_schema
    config = {
      path:  @fn,
      schema_root: '/'
    }

    storage = Syntropy::Storage.new(
      @machine,
      @module_loader,
      config
    )

    schema = storage.schema
    assert_kind_of Syntropy::Schema, schema

    cp = storage.connection_pool
    assert_nil schema.current_version(cp)
    schema.apply(cp)
    assert_equal '2026-05-30-bar', schema.current_version(cp)

    assert_equal [
      {
        id: 1,
        title: 'foo',
        body: 'baz'
      }
    ], cp.query('select id, title, body from posts')
  end

  def test_storage_query
    config = { path:  @fn }
    storage = Syntropy::Storage.new(
      @machine,
      @module_loader,
      config
    )

    r = storage.query('select :foo as a, 42 as b', foo: 'bar')
    assert_equal [{ a: 'bar', b: 42 }], r
  end

  def test_connection_pool_prepare_splat
    # pq = Syntropy::Storage.prepare_splat('select ?')
    # assert_kind_of Syntropy::PreparedQuery, pq
    # assert_equal 'select ?', pq.sql
    # assert_equal :prepare_splat, pq.mode

    # assert_kind_of Extralite::Query, @cp.with_db { it[pq] }
    # assert_equal ['foo'], @cp.with_db { it[pq].bind('foo').to_a }
  end


end
