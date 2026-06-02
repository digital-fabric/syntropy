# frozen_string_literal: true

require_relative './request/request_info'
require_relative './request/validation'
require_relative './request/response'
require_relative './session'
require_relative './http/status'

module Syntropy
  # Syntropy::Request represents an HTTP request. By interacting with the
  # request, the app can extract request information and respond to the request.
  class Request
    include RequestInfoMethods
    include RequestValidationMethods
    include ResponseMethods
    extend RequestInfoClassMethods

    attr_reader :headers, :adapter, :start_stamp, :route_params
    attr_accessor :route

    # Initializes the request.
    #
    # @param headers [Hash] request headers
    # @param adapter [Object] connection adapter
    # @return [void]
    def initialize(headers, adapter)
      @headers  = headers
      @adapter  = adapter
      @start_stamp = ::Process.clock_gettime(::Process::CLOCK_MONOTONIC)
      @route = nil
      @route_params = {}
      @ctx = nil
    end

    # Returns the request context, used to store auxiliary information.
    #
    # @return [Hash] request context hash
    def ctx
      @ctx ||= {}
    end

    # Returns the next request body chunk.
    #
    # @return [String, nil]
    def next_chunk
      @adapter.get_body_chunk(self)
    end

    # Reads request body chunks until the entire body is consumed, yielding each
    # chunk to the given block.
    #
    # @return [void]
    def each_chunk
      while (chunk = @adapter.get_body_chunk(self))
        yield chunk
      end
    end

    # Reads the request body.
    #
    # @return [String, nil] request body
    def read
      @adapter.get_body(self)
    end
    alias_method :body, :read

    # Returns true if the request body has been consumed.
    #
    # @return [bool]
    def complete?
      @adapter.complete?(self)
    end

    EMPTY_HEADERS = {}.freeze

    # Sends a response.
    #
    # @param body [String, nil] response body
    # @param headers [Hash] response headers
    # @return [void]
    def respond(body, headers = EMPTY_HEADERS)
      @adapter.respond(self, body, headers)
      @headers_sent = true
    end

    # Sends response headers.
    #
    # @param headers [Hash] response headers
    # @param empty_response [bool] body should be sent
    # @return [void]
    def send_headers(headers = EMPTY_HEADERS, empty_response = false)
      return if @headers_sent

      @headers_sent = true
      @adapter.send_headers(self, headers, empty_response: empty_response)
    end

    # Sends a response body chunk.
    #
    # @param body [String] response body chunk
    # @param done [bool] body is complete
    # @return [void]
    def send_chunk(body, done: false)
      send_headers({}) unless @headers_sent

      @adapter.send_chunk(self, body, done: done)
    end
    alias_method :<<, :send_chunk

    # Finish response.
    #
    # @return [void]
    def finish
      send_headers({}) unless @headers_sent

      @adapter.finish(self)
    end

    # Returns true if response headers were sent.
    #
    # @return [bool]
    def headers_sent?
      @headers_sent
    end

    # Returns the request session.
    #
    # @return [Syntropy::Session]
    def session
      @session ||= Session.new(self)
    end

    # Returns the request flash session storage.
    #
    # @return [Syntropy::Session::Flash]
    def flash
      session.flash
    end
  end
end
