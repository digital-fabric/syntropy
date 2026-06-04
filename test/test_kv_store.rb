# frozen_string_literal: true

require_relative 'helper'
require 'syntropy/db/kv_store'

class KVStoreTest < Minitest::Test
  def setup
    @machine = UM.new
    @fn = "/tmp/#{rand(100000)}.db"
    FileUtils.rm(@fn) rescue nil
    @cp = Syntropy::DB::ConnectionPool.new(@machine, @fn, 4)
  end

  def teardown
    @cp.close
  end

  def test_connection_pool_prepare
    pq = Syntropy::DB.prepare('select ? as a, 42 as b')
    assert_kind_of Syntropy::DB::PreparedQuery, pq
    assert_equal 'select ? as a, 42 as b', pq.sql
    assert_equal :prepare, pq.mode

    assert_kind_of Extralite::Query, @cp.with_db { it[pq] }
    assert_equal [{ a: 'foo', b: 42 }], @cp.with_db { it[pq].bind('foo').to_a }
  end

  def test_connection_pool_prepare_splat
    pq = Syntropy::DB.prepare_splat('select ?')
    assert_kind_of Syntropy::DB::PreparedQuery, pq
    assert_equal 'select ?', pq.sql
    assert_equal :prepare_splat, pq.mode

    assert_kind_of Extralite::Query, @cp.with_db { it[pq] }
    assert_equal ['foo'], @cp.with_db { it[pq].bind('foo').to_a }
  end

  def test_kv_store_apply_schema
    assert_respond_to Syntropy::DB::KVStore, :apply_schema

    assert_raises(Extralite::SQLError) { @cp.query('select * from kv') }
    Syntropy::DB::KVStore.apply_schema(@cp, 'kv')
    assert_equal [], @cp.query('select * from kv')
  end

  def test_kv_store_get_set
    Syntropy::DB::KVStore.apply_schema(@cp, 'kv')
    kv_store = Syntropy::DB::KVStore.new(@cp, 'kv')

    @cp.with_db do |db|
      assert_nil kv_store.get(db, 'foo')
      assert_nil kv_store.get(db, 'bar')

      kv_store.set(db, 'foo', '123')

      assert_equal '123', kv_store.get(db, 'foo')
      assert_nil kv_store.get(db, 'bar')

      kv_store.set(db, 'bar', '456')
      assert_equal '123', kv_store.get(db, 'foo')
      assert_equal '456', kv_store.get(db, 'bar')
    end
  end

  def test_kv_store_setex_sweep
    Syntropy::DB::KVStore.apply_schema(@cp, 'kv')
    kv_store = Syntropy::DB::KVStore.new(@cp, 'kv')

    @cp.with_db do |db|
      kv_store.set(db, 'foo', '123')
      kv_store.setex(db, 'bar', '456', 0.05)
      assert_equal 0, kv_store.sweep(db)

      assert_equal '123', kv_store.get(db, 'foo')
      assert_equal '456', kv_store.get(db, 'bar')

      sleep 0.1
      assert_equal 1, kv_store.sweep(db)

      assert_equal '123', kv_store.get(db, 'foo')
      assert_nil kv_store.get(db, 'bar')
    end
  end
end
