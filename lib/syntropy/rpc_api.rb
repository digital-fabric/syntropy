# frozen_string_literal: true

require 'qeweney'
require 'syntropy/errors'
require 'json'

module Syntropy
  class RPCAPI
    def call(req)
      response, status = invoke(req)
      req.respond(
        response.to_json,
        ':status'       => status,
        'Content-Type'  => 'application/json'
      )
    end

    def invoke(req)
      q = req.validate_param(:q, String)
      response = case req.method
      when 'get'
        send(q.to_sym, req)
      when 'post'
        send(:"#{q}!", req)
      else
        raise Syntropy::Error.new(Qeweney::Status::METHOD_NOT_ALLOWED)
      end
      [{ status: 'OK', response: response }, Qeweney::Status::OK]
    rescue => e
      if !e.is_a?(Syntropy::Error)
        p e
        p e.backtrace
      end
      error_response(e)
    end

    INTERNAL_SERVER_ERROR = Qeweney::Status::INTERNAL_SERVER_ERROR

    def error_response(err)
      http_status = err.respond_to?(:http_status) ? err.http_status : INTERNAL_SERVER_ERROR
      error_name = err.class.name
      [{ status: error_name, message: err.message }, http_status]
    end
  end
end
