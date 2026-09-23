# frozen_string_literal: true

require_relative 'helper'
require 'syntropy/test'

class CmdNewTemplateTest < Syntropy::Test
  def env
    {
      mode: 'test',
      app_root: File.join(__dir__, '../cmd/new/template/app'),
      config_root: File.join(__dir__, '../cmd/new/template/config'),
      mount_path: '/'
    }
  end

  def test_cmd_new_template_server
    req = get('/foo')
    assert_equal HTTP::NOT_FOUND, req.response_status

    req = get('/')
    assert_equal HTTP::OK, req.response_status
    assert_equal 'text/html', req.response_content_type
  end

  def test_cmd_new_template_storage
    storage = load_module('_lib/storage')
    refute_nil storage

    cp = storage.connection_pool
    assert_kind_of Syntropy::ConnectionPool, cp

    schema = storage.schema
    assert_kind_of Syntropy::Schema, schema

    # migration already ran
    refute_nil schema.current_version(cp)
  end
end
