# frozen_string_literal: true

require_relative 'helper'

class CollectionTest < Minitest::Test
  COLLECTION_ROOT = File.join(__dir__, 'fixtures/collection/basic/_articles')

  def setup
    @machine = UM.new
    @collection = Syntropy::Collection.new(
      machine:  @machine,
      root:     COLLECTION_ROOT,
      url_base: '/apps/blog'
    )
  end

  def test_collection_setup
    assert_equal COLLECTION_ROOT, @collection.root
    assert_equal '/apps/blog', @collection.url_base
  end

  def test_collection_list
    list = @collection.list
    assert_kind_of Array, list
    assert_equal 3, list.size

    foo = list[0]
    assert_kind_of Hash, foo
    assert_equal({
      fn:   File.join(COLLECTION_ROOT, '2026-06-30-foo.md'),
      ref:  '2026-06-30-foo',
      url:  '/apps/blog/2026-06-30-foo',
      type: :markdown,
      attributes: {
        date:     Date.parse('2026-06-30'),
        title:    'FooFoo',
        category: ['a', 'b'],
        author:   'Bar Baz',
      },
      body: 'Foo foo foo.'
    }, foo)

    bar = list[1]
    assert_kind_of Hash, foo
    assert_equal({
      fn:   File.join(COLLECTION_ROOT, '2026-07-13-bar.md'),
      ref:  '2026-07-13-bar',
      url:  '/apps/blog/2026-07-13-bar',
      type: :markdown,
      attributes: {
        date:     Date.parse('2026-07-13'),
        title:    'BarBar',
        category: ['b', 'c'],
        author:   'Baz Foo',
      },
      body: 'Bar bar bar.'
    }, bar)
  end

  def test_collection_get
    assert_nil @collection.get('/')
    assert_nil @collection.get('/apps/blog')

    item = @collection.get('/apps/blog/2026-06-30-foo')
    assert_kind_of Hash, item
    assert_equal({
      fn:   File.join(COLLECTION_ROOT, '2026-06-30-foo.md'),
      ref:  '2026-06-30-foo',
      url:  '/apps/blog/2026-06-30-foo',
      type: :markdown,
      attributes: {
        date:     Date.parse('2026-06-30'),
        title:    'FooFoo',
        category: ['a', 'b'],
        author:   'Bar Baz',
      },
      body: 'Foo foo foo.'
    }, item)
  end
end

class CollectionAppTest < Syntropy::Test
  self.env = {
    app_root: File.join(__dir__, 'fixtures/collection/basic'),
    mount_path: '/blog'
  }

  def test_collection_app_controller
    req = get('/blog/2026-06-30-foo')
    assert_equal HTTP::OK, req.response_status

    assert_equal ['/index+'], app.module_loader.modules.keys

    app.module_loader.invalidate_fn(File.join(env[:app_root], '_articles/2026-06-30-foo.md'))
    assert_equal [], app.module_loader.modules.keys
  end

  def test_collection_module_invalidation
    
  end
end
