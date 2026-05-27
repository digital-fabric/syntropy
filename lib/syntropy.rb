# frozen_string_literal: true

require 'uringmachine'
require 'papercraft'

require 'syntropy/request'
require 'syntropy/logger'
require 'syntropy/http'
require 'syntropy/mime_types'
require 'syntropy/app'
require 'syntropy/connection_pool'
require 'syntropy/errors'
require 'syntropy/markdown'
require 'syntropy/module'
require 'syntropy/papercraft_extensions'
require 'syntropy/routing_tree'
require 'syntropy/json_api'
require 'syntropy/side_run'
require 'syntropy/utils'
require 'syntropy/version'

module Syntropy
  extend Utilities

  class << self
    attr_accessor :machine

    def side_run(&block)
      raise 'Syntropy.machine not set' if !@machine

      SideRun.call(@machine, &block)
    end
  end

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

        env[:logger]&.info(message: "Running Syntropy #{Syntropy::VERSION}, UringMachine #{UM::VERSION}, Ruby #{RUBY_VERSION}")

        server = HTTP::Server.new(machine, env, &app)

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
