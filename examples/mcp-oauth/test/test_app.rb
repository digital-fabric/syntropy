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
end
