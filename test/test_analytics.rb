# frozen_string_literal: true

require_relative 'helper'
require 'securerandom'

class AnalyticsTest < Minitest::Test
  HTTP = Syntropy::HTTP
  ROOT = File.join(__dir__, 'fixtures/base')

  def setup
    @machine = UM.new
    @fn = "/tmp/#{SecureRandom.hex(8)}.db"
    @cp = Syntropy::ConnectionPool.new(@machine, @fn, 2)

    FileUtils.rm(@fn) rescue nil
    @db = Extralite::Database.new(@fn)
    @analytics = Syntropy::Analytics.new(@cp)

    @app = Syntropy::App.load(
      ROOT,
      {
        mount_path: '/test',
        watch_files: 0.05,
        machine: @machine
      }
    )
    @test_harness = Syntropy::TestHarness.new(@app)
  end

  def test_analytics_schema
    assert_equal ['impressions'], @db.tables
    assert_equal [], @db.query('select * from impressions')
  end

  def test_analytics_process_request
    req = @test_harness.request(
      ':method' => 'GET',
      ':path' => '/test/about/foo?bar=1',
      ':scheme' => 'https',
      'host' => 'syntropy.dev',
      'user-agent' => 'UA-blah',
      'x-forwarded-for' => '1.2.3.4',
      'referer' => 'https://syntropy.dev/'
    )
    assert_equal 'text/html; charset=utf-8', req.response_headers['Content-Type']

    t = Time.now.to_i
    @analytics.process_request(req)
    records = @db.query('select * from impressions')
    assert_equal 1, records.size
    r = records.first
    assert r[:stamp] - t <= 1, "record stamp should equal current time"
    assert_equal 'https://syntropy.dev/test/about/foo', r[:url]
    assert_equal 'UA-blah', r[:user_agent]
    assert_equal 'https://syntropy.dev/', r[:referrer]
    refute_nil r[:client_hash]
  end

  def test_analytics_process_request_put
    req = @test_harness.request(
      ':method' => 'PUT',
      ':path' => '/test/by_method',
      ':scheme' => 'https',
      'host' => 'syntropy.dev',
      'user-agent' => 'UA-blah',
      'x-forwarded-for' => '1.2.3.4',
      'referer' => 'https://syntropy.dev/'
    )
    assert_equal 'text/html; charset=utf-8', req.response_headers['Content-Type']
    @analytics.process_request(req)
    assert_equal [], @db.query('select * from impressions')
  end

  def test_analytics_process_request_non_html
    req = @test_harness.request(
      ':method' => 'GET',
      ':path' => '/test/assets/style.css',
      ':scheme' => 'https',
      'host' => 'syntropy.dev',
      'user-agent' => 'UA-blah',
      'x-forwarded-for' => '1.2.3.4',
      'referer' => 'https://syntropy.dev/'
    )
    assert_equal 'text/css', req.response_headers['Content-Type']
    @analytics.process_request(req)
    assert_equal [], @db.query('select * from impressions')
  end

  def test_analytics_process_request_error_response
    req = @test_harness.request(
      ':method' => 'GET',
      ':path' => '/test/about/raise',
      ':scheme' => 'https',
      'host' => 'syntropy.dev',
      'user-agent' => 'UA-blah',
      'x-forwarded-for' => '1.2.3.4',
      'referer' => 'https://syntropy.dev/'
    )
    assert_equal 'text/html', req.response_headers['Content-Type']
    assert_equal 500, req.response_status
    @analytics.process_request(req)
    assert_equal [], @db.query('select * from impressions')
  end

end
