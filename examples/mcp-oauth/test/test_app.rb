# frozen_string_literal: true

require_relative 'helper'

class AppTest < Minitest::Test
  APP_ROOT = File.expand_path(File.join(__dir__, '../app'))
  HTTP = Syntropy::HTTP

  def setup
    @machine = UM.new
    @app = Syntropy::App.new(
      root_dir: APP_ROOT,
      mount_path: '/',
      machine: @machine
    )
    @test_harness = Syntropy::TestHarness.new(@app)
  end

  def test_root
    req = @test_harness.request(
      ':method' => 'GET',
      ':path'   => '/'
    )
    assert_equal HTTP::OK, req.response_status
    assert_match /Syntropy/, req.response_body
  end

  def test_mcp_no_auth
    req = @test_harness.request(
      {
        ':method'       => 'POST',
        ':path'         => '/mcp',
        'Content-Type'  => 'application/json'
      },
      JSON.dump({
        method: 'initialize',
        jsonrpc: '2.0',
        params: {}
      })
    )
    assert_equal HTTP::UNAUTHORIZED, req.response_status

    www_auth = req.response_headers['WWW-Authenticate']
    assert_match /realm="mcp"/, www_auth
    assert_match /#{'resource_metadata="http://localhost:1234/.well-known/mcp-oauth"'}/, www_auth
  end

  def test_oauth_authorization_server
    req = @test_harness.request(
      ':method' => 'GET',
      ':path'   => '/.well-known/mcp-oauth'
    )
    assert_equal HTTP::OK, req.response_status
    json = req.response_json
    assert_equal ["mcp:read", "mcp:write", "offline_access"], json[:scopes_supported]
  end

end
