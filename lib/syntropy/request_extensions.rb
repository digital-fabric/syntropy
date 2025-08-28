# frozen_string_literal: true

require 'qeweney'

module Syntropy
  module RequestExtensions
    attr_reader :route_params

    def initialize(headers, adapter)
      @headers  = headers
      @adapter  = adapter
      @route_params = {}
      @ctx = nil
    end

    def ctx
      @ctx ||= {}
    end

    def validate_http_method(*accepted)
      raise Syntropy::Error.method_not_allowed if !accepted.include?(method)
    end

    def respond_by_http_method(map)
      value = map[self.method]
      raise Syntropy::Error.method_not_allowed if !value

      value = value.() if value.is_a?(Proc)
      (body, headers) = value
      respond(body, headers)
    end

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

    def validate_param(name, *clauses)
      value = query[name]
      clauses.each do |c|
        valid = param_is_valid?(value, c)
        raise(Syntropy::ValidationError, 'Validation error') if !valid

        value = param_convert(value, c)
      end
      value
    end

    private

    BOOL_REGEXP = /^(t|f|true|false|on|off|1|0|yes|no)$/
    BOOL_TRUE_REGEXP = /^(t|true|on|1|yes)$/
    INTEGER_REGEXP = /^[+-]?[0-9]+$/
    FLOAT_REGEXP = /^[+-]?[0-9]+(\.[0-9]+)?$/

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
