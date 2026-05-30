# frozen_string_literal: true

require_relative 'helper'

class DBStoreTest < Minitest::Test
  def setup
    @machine = UM.new
    @fn = "/tmp/#{rand(100000)}.db"
    FileUtils.rm(@fn) rescue nil
    @cp = Syntropy::DB::ConnectionPool.new(@machine, @fn, 4)
  end

  def teardown
    @cp.close
  end

  def test_db_store
    store = Syntropy::DB::Store.new(@cp)

    assert_equal [{a: 42}], store.query("select ? as a", 42)
    assert_equal({a: 42}, store.query_single_row("select ? as a", 42))
    assert_equal 42, store.query_single_value("select ?", 42)
  end
end
