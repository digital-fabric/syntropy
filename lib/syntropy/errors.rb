# frozen_string_literal: true

require 'syntropy/http/status'

module Syntropy
  # The base Syntropy error class
  class Error < StandardError
    # By default, the HTTP status for errors is 500 Internal Server Error.
    DEFAULT_STATUS = HTTP::INTERNAL_SERVER_ERROR

    # Returns the HTTP status for the given exception.
    #
    # @param err [Exception] exception
    # @return [Integer, String] HTTP status
    def self.http_status(err)
      err.respond_to?(:http_status) ? err.http_status : DEFAULT_STATUS
    end

    # Returns true if the error should be logged. Currently all errors are
    # logged except for NOT FOUND errors.
    #
    # @param err [Exception] error
    # @return [bool]
    def self.log_error?(err)
      http_status(err) != HTTP::NOT_FOUND
    end

    # Creates an error with status 404 Not Found.
    #
    # @param msg [String] error message
    # @return [Syntropy::Error]
    def self.not_found(msg = 'Not found') = new(msg, HTTP::NOT_FOUND)

    # Creates an error with status 405 Method Not Allowed.
    #
    # @param msg [String] error message
    # @return [Syntropy::Error]
    def self.method_not_allowed(msg = 'Method not allowed') = new(msg, HTTP::METHOD_NOT_ALLOWED)

    # Creates an error with status 418 I'm a teapot.
    #
    # @param msg [String] error message
    # @return [Syntropy::Error]
    def self.teapot(msg = 'I\'m a teapot') = new(msg, HTTP::TEAPOT)

    attr_reader :http_status

    # Initializes a Syntropy error with the given HTTP status and message.
    #
    # @param http_status [Integer, String] HTTP status
    # @param msg [String] error message
    # @return [void]
    def initialize(msg = 'Internal server error', http_status = DEFAULT_STATUS)
      super(msg)
      @http_status = http_status
    end

    # Returns the HTTP status for the error.
    #
    # @return [Integer, String] HTTP status
    def http_status
      @http_status || HTTP::INTERNAL_SERVER_ERROR
    end
  end

  # ValidationError is raised when a validation has failed.
  class ValidationError < Error
    def initialize(msg)
      super(msg, HTTP::BAD_REQUEST)
    end
  end

  class ProtocolError < Error
    def http_status
      HTTP::BAD_REQUEST
    end
  end

  class UnsupportedHTTPVersionError < ProtocolError
    def http_status
      HTTP::HTTP_VERSION_NOT_SUPPORTED
    end
  end

  class BadRequestError < Error
  end

  class InvalidRequestContentTypeError < Error
    def http_status
      HTTP::UNSUPPORTED_MEDIA_TYPE
    end
  end
end
