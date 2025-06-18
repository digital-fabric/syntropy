# frozen_string_literal: true

require 'qeweney'
require 'syntropy/errors'
require 'json'

module Syntropy
  class RPCAPI
    def initialize(mount_path)
      @mount_path = mount_path
    end

    def call(ctx)
      response, status = invoke(ctx)
      ctx.request.respond(
        response.to_json,
        ':status'       => status,
        'Content-Type'  => 'application/json'
      )
    end

    def invoke(ctx)
      q = ctx.validate_param(:q, String)
      response = case ctx.request.method
      when 'get'
        send(q.to_sym, ctx)
      when 'post'
        send(:"#{q}!", ctx)
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
