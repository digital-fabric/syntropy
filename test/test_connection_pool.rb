# frozen_string_literal: true

require_relative 'helper'

class ConnectionPoolTest < Minitest::Test
  def setup
    @machine = UM.new
    @fn = "/tmp/#{rand(100000)}.db"
    @cp = Syntropy::ConnectionPool.new(@machine, @fn, 4)

    FileUtils.rm(@fn) rescue nil
    @standalone_db = Extralite::Database.new(@fn)
    @standalone_db.execute("create table foo (x, y, z)")
    @standalone_db.execute("insert into foo values (1, 2, 3)")
    @standalone_db.execute("insert into foo values (4, 5, 6)")
  end

  def teardown
    @standalone_db.close
    @cp.close
  end

  def test_connection_pool_with_db
    assert_equal 0, @cp.count

    @cp.with_db do |db|
      assert_kind_of Extralite::Database, db

      records = db.query("select * from foo")
      assert_equal [{x: 1, y: 2, z: 3}, {x: 4, y: 5, z: 6}], records
    end

    assert_equal 1, @cp.count
    @cp.with_db { |db| assert_kind_of Extralite::Database, db }
    assert_equal 1, @cp.count

    dbs = []
    ff = (1..2).map { |i|
      @machine.spin {
        @cp.with_db { |db|
          dbs << db
          @machine.sleep(0.05)
          db.execute("insert into foo values (?, ?, ?)", i * 10 + 1, i * 10 + 2, i * 10 + 3)
        }
      }
    }
    @machine.join(*ff)

    assert_equal 2, dbs.size
    assert_equal 2, dbs.uniq.size
    assert_equal 2, @cp.count

    records = @standalone_db.query("select * from foo order by x")
    assert_equal [
      {x: 1, y: 2, z: 3},
      {x: 4, y: 5, z: 6},
      {x: 11, y: 12, z: 13},
      {x: 21, y: 22, z: 23},
    ], records


    dbs = []
    ff = (1..10).map { |i|
      @machine.spin {
        @cp.with_db { |db|
          dbs << db
          @machine.sleep(0.05 + rand * 0.05)
          db.execute("insert into foo values (?, ?, ?)", i * 10 + 1, i * 10 + 2, i * 10 + 3)
        }
      }
    }
    @machine.join(*ff)

    assert_equal 10, dbs.size
    assert_equal 4, dbs.uniq.size
    assert_equal 4, @cp.count
  end

  def test_connection_pool_with_db_reentrant
    dbs = @cp.with_db do |db1|
      @cp.with_db do |db2|
        [db1, db2]
      end
    end

    assert_equal 1, dbs.uniq.size
  end

  def test_connection_pool_query
    rows = @cp.query('select * from foo')
    assert_equal [{x: 1, y: 2, z: 3}, {x: 4, y: 5, z: 6}], rows
  end

  def test_connection_pool_query_params
    rows = @cp.query('select * from foo where y = ?', 5)
    assert_equal [{x: 4, y: 5, z: 6}], rows

    rows = @cp.query('select * from foo where y = ?', 55)
    assert_equal [], rows
  end

  def test_connection_pool_query_transform_params
    t = ->(r) { r[:z] }
    
    rows = @cp.query(t, 'select * from foo where y <= ?', 5)
    assert_equal [3, 6], rows

    rows = @cp.query(t, 'select * from foo where y = ?', 55)
    assert_equal [], rows
  end

  def test_connection_pool_query_single_row
    row = @cp.query_single_row('select * from foo where x = 1')
    assert_equal({x: 1, y: 2, z: 3}, row)

    row = @cp.query_single_row('select * from foo where x = 3')
    assert_nil row
  end

  def test_connection_pool_query_single_row_params
    row = @cp.query_single_row('select * from foo where x = ?', 1)
    assert_equal({x: 1, y: 2, z: 3}, row)

    row = @cp.query_single_row('select * from foo where x = :x', x: 4)
    assert_equal({x: 4, y: 5, z: 6}, row)

    row = @cp.query_single_row('select * from foo where x = ?', 42)
    assert_nil row
  end

  def test_connection_pool_query_single_row_transform_params
    t = ->(r) { r[:z] }
    
    row = @cp.query_single_row(t, 'select * from foo where x = ?', 1)
    assert_equal(3, row)

    row = @cp.query_single_row(t, 'select * from foo where x = :x', x: 4)
    assert_equal(6, row)

    row = @cp.query_single_row(t, 'select * from foo where x = ?', 42)
    assert_nil row
  end

  def test_connection_pool_query_single_value
    v = @cp.query_single_value('select y from foo where x = 1')
    assert_equal 2, v

    v = @cp.query_single_value('select * from foo where x = 3')
    assert_nil v
  end

  def test_connection_pool_query_single_value_params
    v = @cp.query_single_value('select y from foo where x = ?', 1)
    assert_equal 2, v

    v = @cp.query_single_value('select y from foo where x = :x', x: 4)
    assert_equal 5, v

    v = @cp.query_single_value('select * from foo where x = ?', 3)
    assert_nil v
  end
end
