# frozen_string_literal: true

require 'qeweney'

module Syntropy
  module RequestExtensions
    def ctx
      @ctx ||= {}
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
