# frozen_string_literal: true

require_relative 'helper'

class SchemaTest < Minitest::Test
  def setup
    @machine = UM.new
    @fn = "/tmp/#{rand(100000)}.db"
    FileUtils.rm(@fn) rescue nil
    @cp = Syntropy::Storage::ConnectionPool.new(@machine, @fn, 4)
  end

  def teardown
    @cp.close
  end

  def test_db_schema_initial
    schema = Syntropy::Storage::Schema.new do
      initial do |db|
        db.execute <<~SQL
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
    schema = Syntropy::Storage::Schema.new do
      initial do |db|
        db.execute <<~SQL
          create table posts (
            id integer primary key autoincrement,
            title text,
            body text
          )
        SQL
      end

      version('2026-05-30') do |db|
        db.execute <<~SQL
          insert into posts (title, body)
          values ('foo', 'bar')
        SQL
      end

      version('2026-05-31') do |db|
        db.execute <<~SQL
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

  def test_schema_from_module_files
    module_loader = Syntropy::ModuleLoader.new({
      app_root: File.join(__dir__, 'fixtures/schema')
    })
    schema = Syntropy::Storage::Schema.new(module_loader:, schema_root: '/')

    assert_nil schema.current_version(@cp)
    schema.apply(@cp)
    assert_equal '2026-05-30-bar', schema.current_version(@cp)

    assert_equal [
      {
        id: 1,
        title: 'foo',
        body: 'baz'
      }
    ], @cp.query('select id, title, body from posts')
  end
end
