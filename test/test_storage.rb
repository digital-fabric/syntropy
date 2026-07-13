# frozen_string_literal: true

require_relative 'helper'

class DatabaseExtensionsTest < Minitest::Test
  def setup
    @machine = UM.new
    @fn = "/tmp/#{rand(100000)}.db"
    FileUtils.rm(@fn) rescue nil
    @cp = Syntropy::Storage::ConnectionPool.new(@machine, @fn, 4)
  end

  def teardown
    @cp&.close
  end

  def test_database_query_storage
    @cp.with_db do |db|
      q = db.prepare('select 1')
      db[:foo] = q

      assert_equal q, db[:foo]
    end
  end
end
