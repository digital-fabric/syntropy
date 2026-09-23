# frozen_string_literal: true

require_relative 'helper'

class KVStoreTest < Minitest::Test
  def setup
    @machine = UM.new
    @fn = "/tmp/#{SecureRandom.hex(8)}.db"
    FileUtils.rm(@fn) rescue nil
    @cp = Syntropy::ConnectionPool.new(@machine, @fn, 4)
  end

  def teardown
    @cp&.close
  end

  def test_kv_store_apply_schema
    assert_raises(Extralite::SQLError) { @cp.query('select * from kv') }
    Syntropy::KVStore.new(@cp, 'kv')
    assert_equal [], @cp.query('select * from kv')
  end

  def test_kv_store_get_set
    kv_store = Syntropy::KVStore.new(@cp, 'kv')

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
    kv_store = Syntropy::KVStore.new(@cp, 'kv')

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
