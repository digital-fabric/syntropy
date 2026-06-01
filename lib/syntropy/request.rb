# frozen_string_literal: true

require_relative './request/request_info'
require_relative './request/validation'
require_relative './request/response'
require_relative './http/status'

module Syntropy
  class Request
    include RequestInfoMethods
    include RequestValidationMethods
    include ResponseMethods

    extend RequestInfoClassMethods

    attr_reader :headers, :adapter, :start_stamp, :route_params
    attr_accessor :route

    def initialize(headers, adapter)
      @headers  = headers
      @adapter  = adapter
      @start_stamp = ::Process.clock_gettime(::Process::CLOCK_MONOTONIC)
      @route = nil
      @route_params = {}
      @ctx = nil
    end

    # Returns the request context
    def ctx
      @ctx ||= {}
    end

    def next_chunk
      @adapter.get_body_chunk(self)
    end

    def each_chunk
      while (chunk = @adapter.get_body_chunk(self))
        yield chunk
      end
    end

    def read
      @adapter.get_body(self)
    end
    alias_method :body, :read

    def complete?
      @adapter.complete?(self)
    end

    EMPTY_HEADERS = {}.freeze

    def respond(body, headers = EMPTY_HEADERS)
      @adapter.respond(self, body, headers)
      @headers_sent = true
    end

    def send_headers(headers = EMPTY_HEADERS, empty_response = false)
      return if @headers_sent

      @headers_sent = true
      @adapter.send_headers(self, headers, empty_response: empty_response)
    end

    def send_chunk(body, done: false)
      send_headers({}) unless @headers_sent

      @adapter.send_chunk(self, body, done: done)
    end
    alias_method :<<, :send_chunk

    def finish
      send_headers({}) unless @headers_sent

      @adapter.finish(self)
    end

    def headers_sent?
      @headers_sent
    end

    def rx_incr(count)
      headers[':rx'] ? headers[':rx'] += count : headers[':rx'] = count
    end

    def tx_incr(count)
      headers[':tx'] ? headers[':tx'] += count : headers[':tx'] = count
    end

    def transfer_counts
      [headers[':rx'], headers[':tx']]
    end

    def total_transfer
      (headers[':rx'] || 0) + (headers[':tx'] || 0)
    end

    def session
      @session ||= Session.new(self)
    end
  end
end
