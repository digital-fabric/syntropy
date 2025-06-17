# frozen_string_literal: true

require 'qeweney'

module Syntropy
  class Error < StandardError
    attr_reader :http_status

    def initialize(status, msg = '')
      @http_status = status || Qeweney::Status::INTERNAL_SERVER_ERROR
      super(msg)
    end
  end

  class ValidationError < Error
    def initialize(msg)
      @http_status = Qeweney::Status::BAD_REQUEST
    end
  end
end
