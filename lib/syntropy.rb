# frozen_string_literal: true

require 'qeweney'
require 'uringmachine'
require 'papercraft'

require 'syntropy/logger'
require 'syntropy/connection'
require 'syntropy/server'
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
require 'syntropy/version'

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

  class << self
    def run(env = {}, &app)
      if @in_run
        @env = env
        @env[:app] = app if app
        return
      end

      env ||= @env || {}
      begin
        @in_run = true
        machine = env[:machine] || UM.new
        machine.puts(env[:banner]) if env[:banner]

        env[:logger]&.info(message: "Running Syntropy #{Syntropy::VERSION}, UringMachine #{UM::VERSION}, Ruby #{RUBY_VERSION}")

        server = Server.new(machine, env, &app)

        setup_signal_handling(machine, Fiber.current)
        server.run
      ensure
        @in_run = false
      end
    end

    def env(env = nil, &app)
      return @env if !env && !app

      @env = env || {}
      @env[:app] = app if app
    end

    private

    def setup_signal_handling(machine, fiber)
      queue = UM::Queue.new
      trap('SIGINT') { machine.push(queue, :SIGINT) }
      machine.spin { watch_for_int_signal(machine, queue, fiber) }
    end

    # waits for signal from queue, then terminates given fiber
    # to be done
    def watch_for_int_signal(machine, queue, fiber)
      machine.shift(queue)
      machine.schedule(fiber, UM::Terminate.new)
    end
  end
end
