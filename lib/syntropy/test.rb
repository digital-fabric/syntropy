# frozen_string_literal: true

require 'syntropy'
require 'syntropy/request/mock_adapter'
require 'minitest'

module Syntropy
  class TestHarness
    def initialize(app)
      @app = app
    end

    def request(headers, body = nil)
      req = mock_req(headers, body)
      @app.call(req)
      req
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
      JSON.parse(response_body, symbolize_names: true)
    end

    def response_content_type
      ct = response_headers['Content-Type']
      return nil if !ct

      m = ct.match(/^([^;]+)/)
      return nil if !m

      m[1]
    end
  end
end
