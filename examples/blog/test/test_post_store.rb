# frozen_string_literal: true

class PostStoreTest < Syntropy::Test
  def setup
    super
    @store = load_module('_lib/post_store')
    app.schema.apply(app.connection_pool)
  end

  def test_get_all
    assert_equal [], @store.get_all

    @store.create('foo', 'bar')

    assert_equal [
      { id: 1, title: 'foo', body: 'bar' }
    ], @store.get_all
  end

  def test_get
    assert_nil @store.get(1)
    assert_nil @store.get(2)

    @store.create('foo', 'bar')

    assert_equal(
      { id: 1, title: 'foo', body: 'bar' },
      @store.get(1)
    )
    assert_nil @store.get(2)

    @store.create('bar', 'baz')

    assert_equal(
      { id: 1, title: 'foo', body: 'bar' },
      @store.get(1)
    )
    assert_equal(
      { id: 2, title: 'bar', body: 'baz' },
      @store.get(2)
    )
  end

  def test_update
    assert_equal 0, @store.update(1, 'qqq', 'ttt')

    @store.create('foo', 'bar')
    assert_equal 1, @store.update(1, 'qqq', 'ttt')

    assert_equal [
      { id: 1, title: 'qqq', body: 'ttt' }
    ], @store.get_all
  end

  def test_delete
    assert_equal 0, @store.delete(1)

    @store.create('foo', 'bar')
    @store.create('bar', 'baz')

    assert_equal 1, @store.delete(1)
    assert_equal [
      { id: 2, title: 'bar', body: 'baz' }
    ], @store.get_all
  end
end
