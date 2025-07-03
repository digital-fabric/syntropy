# frozen_string_literal: true

require 'qeweney'
require 'syntropy/errors'
require 'json'

module Syntropy
  class RPCAPI
    def initialize(env)
      @env = env
    end

    def call(req)
      response, status = __invoke__(req)
      req.respond(
        response.to_json,
        ':status'       => status,
        'Content-Type'  => 'application/json'
      )
    end

    private

    def __invoke__(req)
      q = req.validate_param(:q, String).to_sym
      response = case req.method
      when 'get'
        __invoke_get__(q, req)
      when 'post'
        __invoke_post__(q, req)
      else
        raise Syntropy::Error.method_not_allowed
      end
      [{ status: 'OK', response: response }, Qeweney::Status::OK]
    rescue => e
      if !e.is_a?(Syntropy::Error)
        p e
        p e.backtrace
      end
      __error_response__(e)
    end

    def __invoke_get__(sym,  req)
      return send(sym, req) if respond_to?(sym)

      err = respond_to?(:"#{sym}!") ? Syntropy::Error.method_not_allowed : Syntropy::Error.not_found
      raise err
    end

    def __invoke_post__(sym, req)
      sym_post = :"#{sym}!"
      return send(sym_post, req) if respond_to?(sym_post)

      err = respond_to?(sym) ? Syntropy::Error.method_not_allowed : Syntropy::Error.not_found
      raise err
    end

    INTERNAL_SERVER_ERROR = Qeweney::Status::INTERNAL_SERVER_ERROR

    def __error_response__(err)
      http_status = err.respond_to?(:http_status) ? err.http_status : INTERNAL_SERVER_ERROR
      error_name = err.class.name.split('::').last
      [{ status: error_name, message: err.message }, http_status]
    end
  end
end
