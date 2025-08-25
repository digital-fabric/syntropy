# frozen_string_literal: true

require_relative 'helper'
require 'syntropy/routing_tree'

class RoutingTreeTest < Minitest::Test
  FILE_TREE = {
    'site': {

      '[org]': {
        'index.rb': '',
        '[repo]': {
          '_error.rb': '',
          'index.rb': '',
          'commits': {
            'index.rb': ''
          },
          'issues': {
            '_hook.rb': '',
            '[id]': {
              'index.rb': ''
            },
            'index.rb': ''
          },
          '_layout.rb': ''
        }
      },
      '_error.rb': '',
      '_hook.rb': '',
      'about.md': '',
      'index.rb': '',
      'api+.rb': '',
      'assets': {
        'img': {
          'foo.jpg': ''
        },
        'css': {
          'style.css': ''
        }
      },
      'posts': {
        '[id].rb': '',
        'index.rb': ''
      } 
    }
  }

  def setup
    @root_dir = "/tmp/#{__FILE__.gsub('/', '-')}-#{SecureRandom.hex}"
    make_tmp_file_tree(@root_dir, FILE_TREE)
    @rt = RoutingTree.new(root_dir: File.join(@root_dir, 'site'), mount_path: '/docs')
  end

  def test_compute_clean_url_path
    c = ->(fn) { @rt.send(:compute_clean_url_path, fn) }
    assert_equal '/', c.(File.join(@rt.root_dir, '/index.rb'))
    assert_equal '/about', c.(File.join(@rt.root_dir, '/about.md'))
    assert_equal '/[org]', c.(File.join(@rt.root_dir, '/[org]'))
    assert_equal '/favicon.ico', c.(File.join(@rt.root_dir, '/favicon.ico'))
    assert_equal '/assets/style.css', c.(File.join(@rt.root_dir, '/assets/style.css'))
    assert_equal '/foo.js', c.(File.join(@rt.root_dir, '/foo.js'))
  end

  def test_routing_tree
    root = @rt.root
    assert_equal '/docs', root[:path]
    assert_nil root[:parent]
    assert_nil root[:param]
    refute_nil root[:target]
    assert_equal File.join(@rt.root_dir, 'index.rb'), root[:target][:fn]
    assert_equal ['[]', 'about', 'api', 'assets', 'posts'], root[:children].keys.sort_by(&:to_s)

    about = root[:children]['about']
    assert_equal '/docs/about', about[:path]
    assert_equal root, about[:parent]
    assert_equal ({kind: :markdown, fn: File.join(@rt.root_dir, 'about.md')}), about[:target]
    assert_nil about[:children]

    org = root[:children]['[]']
    assert_equal '/docs/[org]', org[:path]
    assert_equal 'org', org[:param]
    refute_nil org[:target]
    assert_equal File.join(@rt.root_dir, '[org]/index.rb'), org[:target][:fn]
    assert_equal ['[]'], org[:children].keys.sort_by(&:to_s)

    repo = org[:children]['[]']
    assert_equal org, repo[:parent]
    assert_equal '/docs/[org]/[repo]', repo[:path]
    assert_equal 'repo', repo[:param]
    assert_equal File.join(@rt.root_dir, '[org]/[repo]/index.rb'), repo[:target][:fn]
    assert_equal ['commits', 'issues'], repo[:children].keys.sort_by(&:to_s)

    issues = repo[:children]['issues']
    assert_equal repo, issues[:parent]
    assert_equal '/docs/[org]/[repo]/issues', issues[:path]
    assert_nil issues[:param]
    assert_equal File.join(@rt.root_dir, '[org]/[repo]/issues/index.rb'), issues[:target][:fn]
    assert_equal ['[]'], issues[:children].keys.sort_by(&:to_s)

    id = issues[:children]['[]']
    assert_equal issues, id[:parent]
    assert_equal '/docs/[org]/[repo]/issues/[id]', id[:path]
    assert_equal 'id', id[:param]
    assert_equal File.join(@rt.root_dir, '[org]/[repo]/issues/[id]/index.rb'), id[:target][:fn]
    assert_equal [], id[:children].keys.sort_by(&:to_s)

    posts = root[:children]['posts']
    assert_equal root, posts[:parent]
    assert_equal '/docs/posts', posts[:path]
    assert_equal File.join(@rt.root_dir, 'posts/index.rb'), posts[:target][:fn]
    assert_equal ['[]'], posts[:children].keys.sort_by(&:to_s)

    id = posts[:children]['[]']
    assert_equal posts, id[:parent]
    assert_equal '/docs/posts/[id]', id[:path]
    assert_equal 'id', id[:param]
    assert_equal File.join(@rt.root_dir, 'posts/[id].rb'), id[:target][:fn]
    assert_nil id[:children]


    # static files are not added to the routing tree, so the assets entry has no children
    assets = root[:children]['assets']
    assert_equal ['css', 'img'], assets[:children].keys.sort
    assert_nil assets[:target]

    assert_nil assets[:children]['css'][:target]
    assert_equal [], assets[:children]['css'][:children].keys
    
    assert_nil assets[:children]['img'][:target]
    assert_equal [], assets[:children]['img'][:children].keys
  end

  def test_static_map
    map = @rt.static_map    
    assert_equal 2, map.size

    o = map['/docs/assets/css/style.css']
    assert_equal File.join(@rt.root_dir, 'assets/css/style.css'), o[:target][:fn]

    o = map['/docs/assets/img/foo.jpg']
    assert_equal File.join(@rt.root_dir, 'assets/img/foo.jpg'), o[:target][:fn]
  end

  def test_dynamic_map
    map = @rt.dynamic_map    
    assert_equal 10, map.size

    keys = map.keys.sort
    assert_equal [
      '/docs', '/docs/[org]', '/docs/[org]/[repo]', '/docs/[org]/[repo]/commits',
      '/docs/[org]/[repo]/issues', '/docs/[org]/[repo]/issues/[id]', '/docs/about',
      '/docs/api+', '/docs/posts', '/docs/posts/[id]'
    ], keys

    # all entries in dynamic map should have targets
    assert_equal [], map.values.select { !it[:target] }

    # all entries should a path equal to the key
    assert_equal ({}), map.select { |k, v| k != v[:path] }

    assert_equal [
      'index.rb',
      '[org]/index.rb',
      '[org]/[repo]/index.rb',
      '[org]/[repo]/commits/index.rb',
      '[org]/[repo]/issues/index.rb',
      '[org]/[repo]/issues/[id]/index.rb',
      'about.md',
      'api+.rb',
      'posts/index.rb',
      'posts/[id].rb'
    ].map { File.join(@rt.root_dir, it) }, keys.map { map[it][:target][:fn] }
  end

  def test_router_proc
    router = @rt.router_proc

    params = {}
    route = router.('/docs/df/p2/issues/14', params)
    assert_equal ({ 'org' => 'df', 'repo' => 'p2', 'id' => '14'}), params
    refute_nil route
    assert_equal '/docs/[org]/[repo]/issues/[id]', route[:path]

    route = router.('/foo', {})
    assert_nil route

    route = router.('/abc/../def', {})
    assert_nil route

    route = router.('/assets', {})
    assert_nil route

    route = router.('/docs/assets', {})
    assert_nil route

    route = router.('/docs/assets/foo', {})
    assert_nil route

    route = router.('/docs/assets/img', {})
    assert_nil route

    route = router.('/docs/assets/foo/bar.jpg', {})
    assert_nil route

    route = router.('/docs/assets/img/foo.jpg', {})
    assert_equal File.join(@rt.root_dir, 'assets/img/foo.jpg'), route[:target][:fn]

    route = router.('/docs/assets/img/bar.jpg', {})
    assert_nil route

    route = router.('/docs/about', {})
    assert_equal File.join(@rt.root_dir, 'about.md'), route[:target][:fn]

    route = router.('/docs/foo', params = {})
    assert_equal File.join(@rt.root_dir, '[org]/index.rb'), route[:target][:fn]
    assert_equal 'foo', params['org']

    route = router.('/docs/foo/bar', params = {})
    assert_equal File.join(@rt.root_dir, '[org]/[repo]/index.rb'), route[:target][:fn]
    assert_equal 'foo', params['org']
    assert_equal 'bar', params['repo']

    route = router.('/docs/bar/baz/commits', params = {})
    assert_equal File.join(@rt.root_dir, '[org]/[repo]/commits/index.rb'), route[:target][:fn]
    assert_equal 'bar', params['org']
    assert_equal 'baz', params['repo']

    route = router.('/docs/foo/bar/issues', params = {})
    assert_equal File.join(@rt.root_dir, '[org]/[repo]/issues/index.rb'), route[:target][:fn]
    assert_equal 'foo', params['org']
    assert_equal 'bar', params['repo']

    route = router.('/docs/bar/baz/issues/14', params = {})
    assert_equal File.join(@rt.root_dir, '[org]/[repo]/issues/[id]/index.rb'), route[:target][:fn]
    assert_equal 'bar', params['org']
    assert_equal 'baz', params['repo']
    assert_equal '14', params['id']

    route = router.('/docs/foo/bar/issues/14/blah', {})
    assert_nil route

    route = router.('/docs/foo/bar/baz', {})
    assert_nil route

    route = router.('/docs/api', {})
    assert_equal File.join(@rt.root_dir, 'api+.rb'), route[:target][:fn]

    route = router.('/docs/api/foo/bar', {})
    assert_equal File.join(@rt.root_dir, 'api+.rb'), route[:target][:fn]

    route = router.('/docs/api/foo/bar', {})
    assert_equal File.join(@rt.root_dir, 'api+.rb'), route[:target][:fn]

    route = router.('/docs/posts', {})
    assert_equal File.join(@rt.root_dir, 'posts/index.rb'), route[:target][:fn]

    route = router.('/docs/posts/foo', params = {})
    assert_equal File.join(@rt.root_dir, 'posts/[id].rb'), route[:target][:fn]
    assert_equal 'foo', params['id']
  end

  def test_route_error_handler
    e = @rt.dynamic_map['/docs/[org]']
    fn = @rt.route_error_handler(e)
    assert_equal File.join(@rt.root_dir, '_error.rb'), fn

    e = @rt.dynamic_map['/docs/api+']
    fn = @rt.route_error_handler(e)
    assert_equal File.join(@rt.root_dir, '_error.rb'), fn

    e = @rt.dynamic_map['/docs/[org]/[repo]']
    fn = @rt.route_error_handler(e)
    assert_equal File.join(@rt.root_dir, '[org]/[repo]/_error.rb'), fn
  end

  def test_route_hooks
    e = @rt.dynamic_map['/docs/[org]']
    hooks = @rt.route_hooks(e)
    assert_equal [File.join(@rt.root_dir, '_hook.rb')], hooks

    e = @rt.dynamic_map['/docs/api+']
    hooks = @rt.route_hooks(e)
    assert_equal [File.join(@rt.root_dir, '_hook.rb')], hooks

    e = @rt.dynamic_map['/docs/[org]/[repo]']
    hooks = @rt.route_hooks(e)
    assert_equal [File.join(@rt.root_dir, '_hook.rb')], hooks

    e = @rt.dynamic_map['/docs/[org]/[repo]/issues']
    hooks = @rt.route_hooks(e)
    assert_equal [
      File.join(@rt.root_dir, '_hook.rb'),
      File.join(@rt.root_dir, '[org]/[repo]/issues/_hook.rb')
    ], hooks

    e = @rt.dynamic_map['/docs/[org]/[repo]/issues/[id]']
    hooks = @rt.route_hooks(e)
    assert_equal [
      File.join(@rt.root_dir, '_hook.rb'),
      File.join(@rt.root_dir, '[org]/[repo]/issues/_hook.rb')
    ], hooks
  end

  def test_routing_root_mounted
    rt = RoutingTree.new(root_dir: File.join(@root_dir, 'site'), mount_path: '/')
    router = rt.router_proc

    route = router.('/docs/df/p2/issues/14', {})
    assert_nil route

    params = {}
    route = router.('/df/p2/issues/14', params)
    refute_nil route
    assert_equal ({ 'org' => 'df', 'repo' => 'p2', 'id' => '14'}), params
    assert_equal '/[org]/[repo]/issues/[id]', route[:path]

    route = router.('/assets', {})
    assert_nil route

    route = router.('/assets/foo', {})
    assert_nil route

    route = router.('/assets/img', {})
    assert_nil route

    route = router.('/assets/foo/bar.jpg', {})
    assert_nil route

    route = router.('/assets/img/foo.jpg', {})
    assert_equal File.join(@rt.root_dir, 'assets/img/foo.jpg'), route[:target][:fn]

    route = router.('/assets/img/bar.jpg', {})
    assert_nil route

    route = router.('/about', {})
    assert_equal File.join(@rt.root_dir, 'about.md'), route[:target][:fn]

    route = router.('/foo', params = {})
    assert_equal File.join(@rt.root_dir, '[org]/index.rb'), route[:target][:fn]
    assert_equal 'foo', params['org']

    route = router.('/foo/bar', params = {})
    assert_equal File.join(@rt.root_dir, '[org]/[repo]/index.rb'), route[:target][:fn]
    assert_equal 'foo', params['org']
    assert_equal 'bar', params['repo']

    route = router.('/bar/baz/commits', params = {})
    assert_equal File.join(@rt.root_dir, '[org]/[repo]/commits/index.rb'), route[:target][:fn]
    assert_equal 'bar', params['org']
    assert_equal 'baz', params['repo']

    route = router.('/foo/bar/issues', params = {})
    assert_equal File.join(@rt.root_dir, '[org]/[repo]/issues/index.rb'), route[:target][:fn]
    assert_equal 'foo', params['org']
    assert_equal 'bar', params['repo']

    route = router.('/bar/baz/issues/14', params = {})
    assert_equal File.join(@rt.root_dir, '[org]/[repo]/issues/[id]/index.rb'), route[:target][:fn]
    assert_equal 'bar', params['org']
    assert_equal 'baz', params['repo']
    assert_equal '14', params['id']

    route = router.('/foo/bar/issues/14/blah', {})
    assert_nil route

    route = router.('/foo/bar/baz', {})
    assert_nil route

    route = router.('/api', {})
    assert_equal File.join(@rt.root_dir, 'api+.rb'), route[:target][:fn]

    route = router.('/api/foo/bar', {})
    assert_equal File.join(@rt.root_dir, 'api+.rb'), route[:target][:fn]

    route = router.('/api/foo/bar', {})
    assert_equal File.join(@rt.root_dir, 'api+.rb'), route[:target][:fn]

    route = router.('/posts', {})
    assert_equal File.join(@rt.root_dir, 'posts/index.rb'), route[:target][:fn]

    route = router.('/posts/foo', params = {})
    assert_equal File.join(@rt.root_dir, 'posts/[id].rb'), route[:target][:fn]
    assert_equal 'foo', params['id']
  end
end
