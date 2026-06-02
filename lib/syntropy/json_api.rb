# frozen_string_literal: true

require 'syntropy/errors'
require 'json'

module Syntropy
  # JSONAPI is a controller that implements a JSON API.
  class JSONAPI
    # Initializes the controller.
    #
    # @param env [Hash] app environment
    # @return [void]
    def initialize(env)
      @env = env
    end

    # Processes the given request.
    #
    # @param req [Syntropy::Request]
    # @return [void]
    def call(req)
      response, status = __invoke__(req)
      req.respond(
        response.to_json,
        ':status'       => status,
        'Content-Type'  => 'application/json'
      )
    end

    private

    # Processes the request by invoking the corresponding object method.
    #
    # @param req [Syntropy::Request]
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
      [{ status: 'OK', response: response }, HTTP::OK]
    rescue StandardError => e
      if !e.is_a?(Syntropy::Error)
        p e
        p e.backtrace
      end
      __error_response__(e)
    end

    # Processes a GET request.
    #
    # @param sym [Symbol] object method
    # @param req [Syntropy::Request] request
    # @return [any] method call return value
    def __invoke_get__(sym,  req)
      return send(sym, req) if respond_to?(sym)

      err = respond_to?(:"#{sym}!") ? Syntropy::Error.method_not_allowed : Syntropy::Error.not_found
      raise err
    end

    # Processes a POST request.
    #
    # @param sym [Symbol] object method
    # @param req [Syntropy::Request] request
    # @return [any] method call return value
    def __invoke_post__(sym, req)
      sym_post = :"#{sym}!"
      return send(sym_post, req) if respond_to?(sym_post)

      err = respond_to?(sym) ? Syntropy::Error.method_not_allowed : Syntropy::Error.not_found
      raise err
    end

    # Generates an error response in case of exception.
    #
    # @param err [Exception] raised Exception
    # @return [Hash] error response
    def __error_response__(err)
      http_status = err.respond_to?(:http_status) ? err.http_status : HTTP::INTERNAL_SERVER_ERROR
      error_name = err.class.name.split('::').last
      [{ status: error_name, message: err.message }, http_status]
    end
  end
end
