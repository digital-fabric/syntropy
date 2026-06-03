# frozen_string_literal: true

class PostsTest < Syntropy::Test
  def setup
    super
    @posts = load_module('/_lib/posts')
  end

  def test_get_all
    assert_equal [], @posts.get_all

    @posts.create('foo', 'bar')

    assert_equal [
      { id: 1, title: 'foo', body: 'bar' }
    ], @posts.get_all
  end

  def test_get
    assert_nil @posts.get(1)
    assert_nil @posts.get(2)

    @posts.create('foo', 'bar')

    assert_equal(
      { id: 1, title: 'foo', body: 'bar' },
      @posts.get(1)
    )
    assert_nil @posts.get(2)

    @posts.create('bar', 'baz')

    assert_equal(
      { id: 1, title: 'foo', body: 'bar' },
      @posts.get(1)
    )
    assert_equal(
      { id: 2, title: 'bar', body: 'baz' },
      @posts.get(2)
    )
  end

  def test_update
    assert_equal 0, @posts.update(1, 'qqq', 'ttt')

    @posts.create('foo', 'bar')
    assert_equal 1, @posts.update(1, 'qqq', 'ttt')

    assert_equal [
      { id: 1, title: 'qqq', body: 'ttt' }
    ], @posts.get_all
  end

  def test_delete
    assert_equal 0, @posts.delete(1)

    @posts.create('foo', 'bar')
    @posts.create('bar', 'baz')

    assert_equal 1, @posts.delete(1)
    assert_equal [
      { id: 2, title: 'bar', body: 'baz' }
    ], @posts.get_all
  end
end
