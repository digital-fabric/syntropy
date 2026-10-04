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
    assert_equal COLLECTION_ROOT, @collection.root_dir
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
    }, foo.slice(:fn, :ref, :url, :type, :attributes, :body))

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
    }, bar.slice(:fn, :ref, :url, :type, :attributes, :body))
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
    }, item.slice(:fn, :ref, :url, :type, :attributes, :body))
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
end

class NestedCollectionTest < Syntropy::Test
  self.env = {
    app_root: File.join(__dir__, 'fixtures/collection/docs'),
    mount_path: '/docs'
  }

  def setup
    super
    @collection = Syntropy::Collection.new(
      machine:  @machine,
      root:     File.join(env[:app_root], '_pages'),
      url_base: '/docs'
    )
  end

  def test_nested_collection_list
    list = @collection.list
    assert_equal 4, list.size

    assert_equal 'FooFoo Foo', list[0][:attributes][:title]
    assert_equal 'FooFoo Bar', list[1][:attributes][:title]
    assert_equal 'BarBar Bar', list[2][:attributes][:title]
    assert_equal 'BarBar Baz', list[3][:attributes][:title]

    assert_nil            list[0][:prev]
    assert_equal list[1], list[0][:next]

    assert_equal list[0], list[1][:prev]
    assert_equal list[2], list[1][:next]

    assert_equal list[1], list[2][:prev]
    assert_equal list[3], list[2][:next]
    
    assert_equal list[2], list[3][:prev]
    assert_nil            list[3][:next]
  end

  def test_nested_collection_dirs
    root_dir = File.join(env[:app_root], '_pages')
    root = @collection.root
    assert_kind_of Hash, root

    assert_equal({
      fn:   nil,
      ref:  '',
      url:  '/docs',
      type: :directory,
    }, root.slice(:fn, :ref, :url, :type))

    assert_equal 2, root[:items].size

    assert_equal({
      fn:   File.join(root_dir, '01-foo/_index.yml'),
      ref:  '01-foo',
      url:  '/docs/01-foo',
      type: :directory
    }, root[:items][0].slice(:fn, :ref, :url, :type))

    assert_equal({
      fn:   File.join(root_dir, '02-bar/_index.yml'),
      ref:  '02-bar',
      url:  '/docs/02-bar',
      type: :directory
    }, root[:items][1].slice(:fn, :ref, :url, :type))
  end
end
