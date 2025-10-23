# frozen_string_literal: true

require 'qeweney'

module Syntropy
  # The base Syntropy error class
  class Error < StandardError
    Status = Qeweney::Status

    # By default, the HTTP status for errors is 500 Internal Server Error
    DEFAULT_STATUS = Status::INTERNAL_SERVER_ERROR

    # Returns the HTTP status for the given exception
    #
    # @param err [Exception] exception
    # @return [Integer, String] HTTP status
    def self.http_status(err)
      err.respond_to?(:http_status) ? err.http_status : DEFAULT_STATUS
    end

    def self.log_error?(err)
      http_status(err) != Status::NOT_FOUND
    end

    # Creates an error with status 404 Not Found
    #
    # @return [Syntropy::Error]
    def self.not_found(msg = 'Not found') = new(msg, Status::NOT_FOUND)

    # Creates an error with status 405 Method Not Allowed
    #
    # @return [Syntropy::Error]
    def self.method_not_allowed(msg = 'Method not allowed') = new(msg, Status::METHOD_NOT_ALLOWED)

    # Creates an error with status 418 I'm a teapot
    #
    # @return [Syntropy::Error]
    def self.teapot(msg = 'I\'m a teapot') = new(msg, Status::TEAPOT)

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
      @http_status || Status::INTERNAL_SERVER_ERROR
    end
  end

  # ValidationError is raised when a validation has failed.
  class ValidationError < Error
    def initialize(msg)
      super(msg, Status::BAD_REQUEST)
    end
  end
end
