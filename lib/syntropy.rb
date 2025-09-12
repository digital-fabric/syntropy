# frozen_string_literal: true

require 'qeweney'
require 'uringmachine'
require 'tp2'
require 'papercraft'

require 'syntropy/app'
require 'syntropy/connection_pool'
require 'syntropy/errors'
require 'syntropy/markdown'
require 'syntropy/module'
require 'syntropy/request_extensions'
require 'syntropy/papercraft_extensions'
require 'syntropy/routing_tree'
require 'syntropy/json_api'
require 'syntropy/side_run'
require 'syntropy/utils'

module Syntropy
  Status = Qeweney::Status

  extend Utilities

  class << self
    attr_accessor :machine

    def side_run(&block)
      raise 'Syntropy.machine not set' if !@machine

      SideRun.call(@machine, &block)
    end
  end

  def colorize(color_code)
    "\e[#{color_code}m#{self}\e[0m"
  end

  GREEN = "\e[32m"
  CLEAR = "\e[0m"
  YELLOW = "\e[33m"

  BANNER =
    "\n"\
    "  #{GREEN}\n"\
    "  #{GREEN} ooo\n"\
    "  #{GREEN}ooooo\n"\
    "  #{GREEN} ooo vvv       #{CLEAR}Syntropy - a web framework for Ruby\n"\
    "  #{GREEN}  o vvvvv     #{CLEAR}--------------------------------------\n"\
    "  #{GREEN}  #{YELLOW}|#{GREEN}  vvv o    #{CLEAR}https://github.com/digital-fabric/syntropy\n"\
    "  #{GREEN} :#{YELLOW}|#{GREEN}:::#{YELLOW}|#{GREEN}::#{YELLOW}|#{GREEN}:\n"\
    "#{YELLOW}+++++++++++++++++++++++++++++++++++++++++++++++++++++++++\e[0m\n\n"
end
