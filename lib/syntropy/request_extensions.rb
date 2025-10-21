# frozen_string_literal: true

require 'qeweney'
require 'json'

module Syntropy
  # Extensions for the Qeweney::Request class
  module RequestExtensions
    attr_reader :route_params
    attr_accessor :route

    # Initializes request with additional fields
    def initialize(headers, adapter)
      @headers  = headers
      @adapter  = adapter
      @route = nil
      @route_params = {}
      @ctx = nil
    end

    # Sets up mock request additional fields
    def setup_mock_request
      @route = nil
      @route_params = {}
      @ctx = nil
    end

    # Returns the request context
    def ctx
      @ctx ||= {}
    end

    # Checks the request's HTTP method against the given accepted values. If not
    # included in the accepted values, raises an exception. Otherwise, returns
    # the request's HTTP method.
    #
    # @param accepted [Array<String>] list of accepted HTTP methods
    # @return [String] request's HTTP method
    def validate_http_method(*accepted)
      raise Syntropy::Error.method_not_allowed if !accepted.include?(method)

      method
    end

    # Responds according to the given map. The given map defines the responses
    # for each method. The value for each method is either an array containing
    # the body and header values to use as response, or a proc returning such an
    # array. For example:
    #
    #     req.respond_by_http_method(
    #       'head'  => [nil, headers],
    #       'get'   => -> { [IO.read(fn), headers] }
    #     )
    #
    # If the request's method is not included in the given map, an exception is
    # raised.
    #
    # @param map [Hash] hash mapping HTTP methods to responses
    # @return [void]
    def respond_by_http_method(map)
      value = map[self.method]
      raise Syntropy::Error.method_not_allowed if !value

      value = value.() if value.is_a?(Proc)
      (body, headers) = value
      respond(body, headers)
    end

    # Responds to GET requests with the given body and headers. Otherwise raises
    # an exception.
    #
    # @param body [String, nil] response body
    # @param headers [Hash] response headers
    # @return [void]
    def respond_on_get(body, headers = {})
      case self.method
      when 'head'
        respond(nil, headers)
      when 'get'
        respond(body, headers)
      else
        raise Syntropy::Error.method_not_allowed
      end
    end

    # Responds to POST requests with the given body and headers. Otherwise
    # raises an exception.
    #
    # @param body [String, nil] response body
    # @param headers [Hash] response headers
    # @return [void]
    def respond_on_post(body, headers = {})
      case self.method
      when 'head'
        respond(nil, headers)
      when 'post'
        respond(body, headers)
      else
      raise Syntropy::Error.method_not_allowed
      end
    end

    # Validates and optionally converts request parameter value for the given
    # parameter name against the given clauses. If no clauses are given,
    # verifies the parameter value is not nil. A clause can be a class, such as
    # String, Integer, etc, in which case the value is converted into the
    # corresponding value. A clause can also be a range, for verifying the value
    # is within the range. A clause can also be an array of two or more clauses,
    # at least one of which should match the value. If the validation fails, an
    # exception is raised. Example:
    #
    #     height = req.validate_param(:height, Integer, 1..100)
    #
    # @param name [Symbol] parameter name
    # @clauses [Array] one or more validation clauses
    # @return [any] validated parameter value
    def validate_param(name, *clauses)
      validate(query[name], *clauses)
    end

    # Validates and optionally converts a value against the given clauses. If no
    # clauses are given, verifies the parameter value is not nil. A clause can
    # be a class, such as String, Integer, etc, in which case the value is
    # converted into the corresponding value. A clause can also be a range, for
    # verifying the value is within the range. A clause can also be an array of
    # two or more clauses, at least one of which should match the value. If the
    # validation fails, an exception is raised.
    #
    # @param value [any] value
    # @clauses [Array] one or more validation clauses
    # @return [any] validated value
    def validate(value, *clauses)
      raise Syntropy::ValidationError, 'Validation error' if clauses.empty? && !value

      clauses.each do |c|
        valid = param_is_valid?(value, c)
        raise(Syntropy::ValidationError, 'Validation error') if !valid

        value = param_convert(value, c)
      end
      value
    end

    # Validates request cache information. If the request cache information
    # matches the given etag or last_modified values, responds with a 304 Not
    # Modified status. Otherwise, yields to the given block for a normal
    # response, and sets cache control headers according to the given arguments.
    #
    # @param cache_control [String] value for Cache-Control header
    # @param etag [String, nil] Etag header value
    # @param last_modified [String, nil] Last-Modified header value
    # @return [void]
    def validate_cache(cache_control: 'public', etag: nil, last_modified: nil)
      validated = false
      if (client_etag = headers['if-none-match'])
        validated = true if client_etag == etag
      end
      if (client_mtime = headers['if-modified-since'])
        validated = true if client_mtime == last_modified
      end
      if validated
        respond(nil, ':status' => Qeweney::Status::NOT_MODIFIED)
      else
        cache_headers = {
          'Cache-Control' => cache_control
        }
        cache_headers['Etag'] = etag if etag
        cache_headers['Last-Modified'] = last_modified if last_modified
        set_response_headers(cache_headers)
        yield
      end
    end

    # Reads the request body and returns form data.
    #
    # @return [Hash] form data
    def get_form_data
      body = read
      if !body || body.empty?
        raise Syntropy::Error.new(Qeweney::Status::BAD_REQUEST, 'Missing form data')
      end

      Qeweney::Request.parse_form_data(body, headers)
    rescue Qeweney::BadRequestError
      raise Syntropy::Error.new(Qeweney::Status::BAD_REQUEST, 'Invalid form data')
    end

    def html_response(html, **headers)
      respond(
        html,
        'Content-Type' => 'text/html; charset=utf-8',
        **headers
      )
    end

    def json_response(obj, **headers)
      respond(
        JSON.dump(obj),
        'Content-Type' => 'application/json; charset=utf-8',
        **headers
      )
    end

    def json_pretty_response(obj, **headers)
      respond(
        JSON.pretty_generate(obj),
        'Content-Type' => 'application/json; charset=utf-8',
        **headers
      )
    end

    def browser?
      user_agent = headers['user-agent']
      user_agent && user_agent =~ /^Mozilla\//
    end

    # Returns true if the accept header includes the given MIME type
    #
    # @param mime_type [String] MIME type
    # @return [bool]
    def accept?(mime_type)
      accept = headers['accept']  
      return nil if !accept

      @accept_parts ||= parse_accept_parts(accept)
      @accept_parts.include?(mime_type)
    end

    private

    def parse_accept_parts(accept)
      accept.split(',').map { it.match(/^\s*([^\s;]+)/)[1] }
    end

    BOOL_REGEXP = /^(t|f|true|false|on|off|1|0|yes|no)$/
    BOOL_TRUE_REGEXP = /^(t|true|on|1|yes)$/
    INTEGER_REGEXP = /^[+-]?[0-9]+$/
    FLOAT_REGEXP = /^[+-]?[0-9]+(\.[0-9]+)?$/

    # Returns true the given value matches the given condition.
    #
    # @param value [any] value
    # @param cond [any] condition
    # @return [bool]
    def param_is_valid?(value, cond)
      return cond.any? { |c| param_is_valid?(value, c) } if cond.is_a?(Array)

      if value
        if cond == :bool
          return value =~ BOOL_REGEXP
        elsif cond == Integer
          return value =~ INTEGER_REGEXP
        elsif cond == Float
          return value =~ FLOAT_REGEXP
        end
      end

      cond === value
    end

    # Converts the given value according to the given class.
    #
    # @param value [any] value
    # @param klass [Class] class
    # @return [any] converted value
    def param_convert(value, klass)
      if klass == :bool
        value =~ BOOL_TRUE_REGEXP ? true : false
      elsif klass == Integer
        value.to_i
      elsif klass == Float
        value.to_f
      elsif klass == Symbol
        value.to_sym
      else
        value
      end
    end
  end
end

Qeweney::Request.include(Syntropy::RequestExtensions)
