# frozen_string_literal: true

require 'syntropy/errors'

module Syntropy
  class Context
    attr_reader :request

    def initialize(request)
      @request = request
    end

    def params
      @request.query
    end

    def validate_param(name, *clauses)
      value = @request.query[name]
      clauses.each do |c|
        valid = is_valid_param?(value, c)
        raise(Syntropy::ValidationError, 'Validation error') if !valid
        if c == Integer
          value = value.to_i
        elsif c == Float
          value = value.to_f
        end
      end
      value
    end

    INTEGER_REGEXP = /^[\+\-]?[0-9]+$/
    FLOAT_REGEXP = /^[\+\-]?[0-9]+(\.[0-9]+)?$/

    def is_valid_param?(value, cond)
      if cond == Integer
        return (value.is_a?(String) && value =~ INTEGER_REGEXP)
      elsif cond == Float
        return (value.is_a?(String) && value =~ FLOAT_REGEXP)
      elsif cond.is_a?(Array)
        return cond.any? { |c| is_valid_param?(value, c) }
      end

      cond === value
    end
  end
end
