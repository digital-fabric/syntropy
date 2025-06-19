# frozen_string_literal: true

require 'qeweney'

require 'syntropy/errors'
# require 'syntropy/context'
require 'syntropy/rpc_api'
require 'syntropy/app'

class Qeweney::Request
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
  INTEGER_REGEXP = /^[\+\-]?[0-9]+$/
  FLOAT_REGEXP = /^[\+\-]?[0-9]+(\.[0-9]+)?$/

  def param_is_valid?(value, cond)
    if cond == :bool
      return (value && value =~ BOOL_REGEXP)
    elsif cond == Integer
      return (value && value =~ INTEGER_REGEXP)
    elsif cond == Float
      return (value && value =~ FLOAT_REGEXP)
    elsif cond.is_a?(Array)
      return cond.any? { |c| param_is_valid?(value, c) }
    end

    cond === value
  end

  def param_convert(value, klass)
    if klass == :bool
      value = value =~ BOOL_TRUE_REGEXP ? true : false
    elsif klass == Integer
      value = value.to_i
    elsif klass == Float
      value = value.to_f
    else
      value
    end
  end
end

module Syntropy
  def colorize(color_code)
    "\e[#{color_code}m#{self}\e[0m"
  end

  GREEN = "\e[32m"
  WHITE = "\e[0m"
  YELLOW = "\e[33m"

  BANNER = (
    "\n"\
    "  #{GREEN}\n"\
    "  #{GREEN} ooo\n"\
    "  #{GREEN}ooooo\n"\
    "  #{GREEN} ooo vvv       #{WHITE}Syntropy - a web framework for Ruby\n"\
    "  #{GREEN}  o vvvvv     #{WHITE}--------------------------------------\n"\
    "  #{GREEN}  #{YELLOW}|#{GREEN}  vvv o    #{WHITE}https://github.com/noteflakes/syntropy\n"\
    "  #{GREEN} :#{YELLOW}|#{GREEN}:::#{YELLOW}|#{GREEN}::#{YELLOW}|#{GREEN}:\n"\
    "  #{YELLOW}++++++++++++\e[0m\n\n"
  )
end
