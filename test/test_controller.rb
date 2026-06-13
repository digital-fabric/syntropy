# frozen_string_literal: true

require_relative 'helper'
require 'syntropy/test'

class DispatchByHostTest < Syntropy::Test
  self.env = {
    app_root: File.join(__dir__, 'fixtures/controllers'),
    mount_path: '/'
  }

  def test_dispatch_by_host_dir
    req = get('/by_host_dir', 'host' => 'sqdf')
    assert_equal HTTP::BAD_REQUEST, req.response_status

    req = get('/by_host_dir', 'host' => 'foo.com')
    assert_equal HTTP::OK, req.response_status
    assert_equal 'foo', req.response_body

    req = get('/by_host_dir', 'host' => 'bar.com')
    assert_equal HTTP::OK, req.response_status
    assert_equal 'bar', req.response_body
  end

  def test_dispatch_by_host_map
    req = get('/by_host_map', 'host' => 'sqdf')
    assert_equal HTTP::BAD_REQUEST, req.response_status

    req = get('/by_host_map', 'host' => 'foofoo')
    assert_equal HTTP::OK, req.response_status
    assert_equal 'foo', req.response_body

    req = get('/by_host_map', 'host' => 'barbar')
    assert_equal HTTP::OK, req.response_status
    assert_equal 'bar', req.response_body
  end

  def test_dispatch_by_host_dir_map
    req = get('/by_host_dir_map', 'host' => 'sqdf')
    assert_equal HTTP::BAD_REQUEST, req.response_status

    req = get('/by_host_dir_map', 'host' => 'foo.com')
    assert_equal HTTP::OK, req.response_status
    assert_equal 'foo', req.response_body

    req = get('/by_host_dir_map', 'host' => 'foofoo')
    assert_equal HTTP::OK, req.response_status
    assert_equal 'foo', req.response_body

    req = get('/by_host_dir_map', 'host' => 'bar.com')
    assert_equal HTTP::OK, req.response_status
    assert_equal 'bar', req.response_body

    req = get('/by_host_dir_map', 'host' => 'barbar')
    assert_equal HTTP::OK, req.response_status
    assert_equal 'bar', req.response_body
  end

  def test_dispatch_by_http_method
    req = get('/by_http_method')
    assert_equal HTTP::OK, req.response_status
    assert_equal 'get', req.response_body

    req = post('/by_http_method', nil, nil)
    assert_equal HTTP::OK, req.response_status
    assert_equal 'post', req.response_body

    req = patch('/by_http_method', nil, nil)
    assert_equal HTTP::METHOD_NOT_ALLOWED, req.response_status
  end
end
