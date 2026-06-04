# frozen_string_literal: true

require 'syntropy'
require 'syntropy/request/mock_adapter'
require 'minitest'
require 'json'
require 'uri'

module Syntropy
  # Test provides a class for testing a Syntropy app, based on Minitest.
  class Test < Minitest::Test
    HTTP = Syntropy::HTTP

    # Sets the app environment for all Syntropy tests.
    #
    # @param env [Hash] app environment hash
    # @return [void]
    def self.env=(env)
      @@env = env
    end

    attr_reader :machine, :app

    # Returns the test environment.
    #
    # @return [Hash] test app environment
    def env
      @@env
    end

    # Loads and returns a module with the given reference.
    #
    # @param ref [String] module reference
    # @return [any] module
    def load_module(ref, raise_on_missing: true)
      app.module_loader.load(ref, raise_on_missing:)
    end

    # Makes an HTTP request to the test app.
    #
    # @param headers [Hash] request headers
    # @param body [String, nil] request body
    # @return [Syntropy::Request]
    def http_request(headers, body = nil)
      @test_harness.request(headers, body)
    end

    # Makes an HTTP GET request to the test app.
    #
    # @param path [String] request path
    # @param headers [Hash] request headers
    # @return [Syntropy::Request]
    def get(path, **headers)
      http_request(
        headers.merge(
          ':method' => 'GET',
          ':path'   => path
        )
      )
    end

    # Makes an HTTP POST request to the test app.
    #
    # @param path [String] request path
    # @param content_type [String, nil] content MIME type
    # @param body [String] request body
    # @param headers [Hash] request headers
    # @return [Syntropy::Request]
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

    # Makes an HTTP POST request to the test app with a "application/json"
    # content type. The given object is converted to JSON and sent as the
    # request body.
    #
    # @param path [String] request path
    # @param data [any] data
    # @return [Syntropy::Request]
    def post_json(path, data, **)
      post(path, 'application/json', JSON.dump(data), **)
    end

    # Makes an HTTP POST request to the test app with a
    # "application/x-www-form-urlencoded" content type. The given data is
    # converted to URL Encoded form format and sent as the request body.
    #
    # @param path [String] request path
    # @param data [Hash] form data
    # @return [Syntropy::Request]
    def post_form(path, data, **)
      post(path, 'application/x-www-form-urlencoded', URI.encode_www_form(data), **)
    end

    # Sets up a test instance.
    #
    # @return [void]
    def setup
      raise 'Environment not set' if !@@env

      Syntropy.load_config(@@env)

      @machine = UM.new
      @app = Syntropy::App.new(
        **@@env.merge(
          machine: @machine,
          test_mode: true
        )
      )
      @test_harness = Syntropy::TestHarness.new(@app)

      @db = load_module('/_lib/storage', raise_on_missing: false)
      @db&.migrate!
    end

    # Cleans up a test instance.
    #
    # @return [void]
    def teardown
      @machine = nil
      @app = nil
      @test_harness = nil
    end
  end

  # TestHarness provides glue code for performing HTTP requests against a
  # Syntropy app.
  class TestHarness
    # Initializes the test harness with the given app.
    #
    # @param app [Syntropy::App]
    # @return [void]
    def initialize(app)
      @app = app
      @app.raise_internal_server_error = true if @app.respond_to?(:raise_internal_server_error=)
    end

    # Perfrms a request against the associated app.
    #
    # @param headers [Hash] request headers
    # @param body [String, nil] request body
    # @return [Syntropy::Request]
    def request(headers, body = nil)
      req = mock_req(headers, body)
      @app.call(req)
      req
    end

    # Temporarily disables raising an exception in case of an internal server
    # error while running the given block.
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

    # Creates a Syntropy request running on a mock adapter.
    #
    # @param headers [Hash] request headers
    # @param body [String, nil] request body
    # @return [Syntropy::Request]
    def mock_req(headers, body = nil)
      Syntropy::MockAdapter.mock(headers, body)
    end
  end

  # Extensions to Syntropy::Request for testing.
  module TestRequestExtensions
    # Returns the response headers.
    #
    # @return [Hash]
    def response_headers
      adapter.response_headers
    end

    # Returns the response status
    #
    # @return [Integer]
    def response_status
      adapter.status
    end

    # Returns the response body
    #
    # @return [String, nil]
    def response_body
      adapter.response_body
    end

    # Parses the response body from JSON.
    #
    # @return [any] parsed JSON object
    def response_json
      raise if response_content_type != 'application/json'
      JSON.parse(response_body)
    end

    # Returns the response content MIME type.
    #
    # @return [String, nil]
    def response_content_type
      ct = response_headers['Content-Type']
      return nil if !ct

      m = ct.match(/^([^;]+)/)
      return nil if !m

      m[1]
    end

    # Returns the cookie value for the given cookie name from the response.
    #
    # @param name [String, Symbol] cookie name
    # @return [String, nil] cookie value
    def response_cookie(name)
      sc = response_headers['Set-Cookie']
      return nil if !sc

      m = sc.match(/#{name}=([^\s]+)$/)
      return nil if !m

      m[1]
    end
  end

  Request.include TestRequestExtensions
end

Syntropy.test_mode = true
