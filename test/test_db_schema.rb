# frozen_string_literal: true

require_relative 'helper'

class DBSchemaTest < Minitest::Test
  def setup
    @machine = UM.new
    @fn = "/tmp/#{rand(100000)}.db"
    FileUtils.rm(@fn) rescue nil
    @cp = Syntropy::DB::ConnectionPool.new(@machine, @fn, 4)
  end

  def teardown
    @cp.close
  end

  def test_db_schema_basic
    schema = Syntropy::DB::Schema.new do
      execute <<~SQL
        create table posts (
          id integer primary key autoincrement,
          title text,
          body text
        )
      SQL
    end

    assert_raises(Extralite::SQLError) { @cp.query('select * from posts') }

    assert_nil schema.current_version(@cp)
    schema.apply(@cp)
    assert_equal '0000', schema.current_version(@cp)

    assert_equal [], @cp.query('select id, title, body from posts')
  end

  def test_db_schema_initial
    schema = Syntropy::DB::Schema.new do
      initial do
        execute <<~SQL
          create table posts (
            id integer primary key autoincrement,
            title text,
            body text
          )
        SQL
      end
    end

    assert_nil schema.current_version(@cp)
    schema.apply(@cp)
    assert_equal '0000', schema.current_version(@cp)

    assert_equal [], @cp.query('select id, title, body from posts')
  end

  def test_db_schema_version_blocks
    schema = Syntropy::DB::Schema.new do
      initial do
        execute <<~SQL
          create table posts (
            id integer primary key autoincrement,
            title text,
            body text
          )
        SQL
      end

      version('2026-05-30') do
        execute <<~SQL
          insert into posts (title, body)
          values ('foo', 'bar')
        SQL
      end

      version('2026-05-31') do
        execute <<~SQL
          update posts
          set body = 'baz'
          where title = 'foo'
        SQL
      end
    end

    assert_nil schema.current_version(@cp)
    schema.apply(@cp)
    assert_equal '2026-05-31', schema.current_version(@cp)

    assert_equal [
      {
        id: 1,
        title: 'foo',
        body: 'baz'
      }
    ], @cp.query('select id, title, body from posts')
  end
end
