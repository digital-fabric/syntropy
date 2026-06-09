# frozen_string_literal: true

require_relative 'helper'
require 'syntropy/test'

class TestTest < Syntropy::Test
  self.env = {
    app_root: File.join(__dir__, 'fixtures/app'),
    mount_path: '/syntest'
  }

  def test_http_request
    req = http_request({
      ':method' => 'GET',
      ':path' => '/syntest'
    })
    assert_kind_of Syntropy::Request, req
    assert_equal HTTP::OK, req.response_status
  end

  def test_env
    assert_kind_of Hash, env
    assert_equal File.join(__dir__, 'fixtures/app'), env[:app_root]
  end

  def test_app
    assert_kind_of Syntropy::App, app
    assert_equal File.join(__dir__, 'fixtures/app'), app.app_root
  end

  def test_machine
    assert_kind_of UM, machine
  end

  def test_load_module
    mod = load_module('_lib/env')
    assert_kind_of Syntropy::ModuleContext, mod
    assert_equal app, mod.app

    assert_raises(Syntropy::Error) { load_module('_lib/blah')}
  end

  def test_get
    req = get('/syntest/bar')
    assert_kind_of Syntropy::Request, req
    assert_equal HTTP::OK, req.response_status
    assert_equal 'foobar', req.response_body
  end

  def test_post
    req = post('/syntest/post_ct', 'text/plain', 'foo')
    assert_kind_of Syntropy::Request, req
    assert_equal HTTP::OK, req.response_status
    assert_equal 'text/plain:foo', req.response_body
  end

  def test_post_json
    req = post_json('/syntest/post_ct', { a: 42, b: [3]})
    assert_kind_of Syntropy::Request, req
    assert_equal HTTP::OK, req.response_status
    assert_equal 'application/json:{"a":42,"b":[3]}', req.response_body
  end

  def test_post_form
    req = post_form('/syntest/post_ct', { a: 'b&c', d: 1})
    assert_kind_of Syntropy::Request, req
    assert_equal HTTP::OK, req.response_status
    assert_equal 'application/x-www-form-urlencoded:a=b%26c&d=1', req.response_body
  end
end
