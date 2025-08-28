# frozen_string_literal: true

require 'qeweney'

module Syntropy
  class Error < StandardError
    Status = Qeweney::Status

    def self.http_status(err)
      err.is_a?(Error) ?
        err.http_status :
        Qeweney::Status::INTERNAL_SERVER_ERROR
    end

    # Create class methods for common errors
    {
      not_found:          Status::NOT_FOUND,
      method_not_allowed: Status::METHOD_NOT_ALLOWED,
      teapot:             Status::TEAPOT
    }
    .each { |k, v|
      singleton_class.define_method(k) { |msg = ''| new(v, msg) }
    }

    attr_reader :http_status

    def initialize(http_status, msg = '')
      super(msg)
      @http_status = http_status
    end

    def http_status
      @http_status || Qeweney::Status::INTERNAL_SERVER_ERROR
    end
  end

  class ValidationError < Error
    def initialize(msg)
      super(Qeweney::Status::BAD_REQUEST, msg)
    end
  end
end
