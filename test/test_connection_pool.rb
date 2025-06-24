# frozen_string_literal: true

require_relative 'helper'

class ConnectionPoolTest < Minitest::Test
  def setup
    @machine = UM.new
    @fn = "/tmp/#{rand(100000)}.db"
    @cp = Syntropy::ConnectionPool.new(@machine, @fn, 4)

    FileUtils.rm(@fn) rescue nil
    @standalone_db = Extralite::Database.new(@fn)
    @standalone_db.execute("create table foo (x,y, z)")
    @standalone_db.execute("insert into foo values (1, 2, 3)")
  end

  def test_with_db
    assert_equal 0, @cp.count

    @cp.with_db do |db|
      assert_kind_of Extralite::Database, db

      records = db.query("select * from foo")
      assert_equal [{x: 1, y: 2, z: 3}], records
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

  def test_with_db_reentrant
    dbs = @cp.with_db do |db1|
      @cp.with_db do |db2|
        [db1, db2]
      end
    end

    assert_equal 1, dbs.uniq.size
  end
end
