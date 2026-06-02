# frozen_string_literal: true

require 'syntropy'
require 'syntropy/request/mock_adapter'
require 'minitest'
require 'json'
require 'uri'

module Syntropy
  class Test < Minitest::Test
    HTTP = Syntropy::HTTP

    def self.env=(env)
      @@env = env
    end

    attr_reader :machine, :app

    def env
      @@env
    end

    def load_module(ref)
      app.module_loader.load(ref)
    end

    def http_request(headers, body = nil)
      @test_harness.request(headers, body)
    end

    def get(path, **headers)
      http_request(
        headers.merge(
          ':method' => 'GET',
          ':path'   => path
        )
      )
    end

    def post(path, content_type, body, **headers)
      headers = headers.merge('content-type' => content_type) if content_type
      http_request(
        headers.merge(
          {
            ':method' => 'POST',
            ':path'   => path
          }
        ),
        body
      )
    end

    def post_json(path, obj, **)
      post(path, 'application/json', JSON.dump(obj), **)
    end

    def post_form(path, form, **)
      post(path, 'application/x-www-form-urlencoded', URI.encode_www_form(form), **)
    end

    def setup
      raise 'Environment not set' if !@@env

      @machine = UM.new
      @app = Syntropy::App.new(
        root_dir: @@env[:root_dir],
        mount_path: @@env[:mount_path] || '/',
        machine: @machine
      )
      @test_harness = Syntropy::TestHarness.new(@app)
    end

    def teardown
      @machine = nil
      @app = nil
      @test_harness = nil
    end
  end

  class TestHarness
    def initialize(app)
      @app = app
      @app.raise_internal_server_error = true if @app.respond_to?(:raise_internal_server_error=)
    end

    def request(headers, body = nil)
      req = mock_req(headers, body)
      @app.call(req)
      req
    end

    def no_raise_internal_server_error
      return yield if !@app.respond_to?(:raise_internal_server_error=)

      begin
        @app.raise_internal_server_error = false
        yield
      ensure
        @app.raise_internal_server_error = true
      end
    end

    private

    def mock_req(headers, body = nil)
      Syntropy::MockAdapter.mock(headers, body)
    end
  end

  class Request
    def response_headers
      adapter.response_headers
    end

    def response_status
      adapter.status
    end

    def response_body
      adapter.response_body
    end

    def response_json
      raise if response_content_type != 'application/json'
      JSON.parse(response_body)
    end

    def response_content_type
      ct = response_headers['Content-Type']
      return nil if !ct

      m = ct.match(/^([^;]+)/)
      return nil if !m

      m[1]
    end

    def response_cookie(name)
      sc = response_headers['Set-Cookie']
      return nil if !sc

      m = sc.match(/#{name}=([^\s]+)$/)
      return nil if !m

      m[1]
    end
  end
end
