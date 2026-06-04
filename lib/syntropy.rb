# frozen_string_literal: true

require 'uringmachine'
require 'papercraft'
require 'yaml'

require 'syntropy/request'
require 'syntropy/logger'
require 'syntropy/http'
require 'syntropy/mime_types'
require 'syntropy/app'
require 'syntropy/storage'
require 'syntropy/errors'
require 'syntropy/markdown'
require 'syntropy/module_loader'
require 'syntropy/papercraft_extensions'
require 'syntropy/routing_tree'
require 'syntropy/json_api'
require 'syntropy/side_run'
require 'syntropy/utils'
require 'syntropy/version'

# Syntropy is a web framework for building web apps in Ruby. Syntropy uses
# UringMachine for I/O and concurrency, and provides a comprehensive and
# flexible solution for writing web apps with minimal boilerplate.
module Syntropy
  extend Utilities

  class << self
    attr_accessor :machine, :dev_mode, :test_mode

    # Runs the given block on a separate thread. Use this method for running
    # code that is not fiber-aware (i.e. does not use UringMachine).
    #
    # @return [any] operation return value
    def side_run(&block)
      raise 'Syntropy.machine not set' if !@machine

      SideRun.call(@machine, &block)
    end

    # Runs a web app with the given environment hash. The given block is either
    # an instance of Syntropy::App, or a Proc/callable that takes a request as
    # argument.
    #
    # @param env [Hash] environment
    # @return [void]
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

        if (logger = env[:logger])
          logger.info(
            message: "Syntropy #{Syntropy::VERSION}, UringMachine #{UM::VERSION}, Ruby #{RUBY_VERSION}"
          )
          logger.info(
            message: "Running in #{env[:mode]} mode"
          )
        end

        server = HTTP::Server.new(machine, env, &app)

        setup_signal_handling(machine, Fiber.current)
        server.run
      ensure
        @in_run = false
      end
    end

    def load_config(env)
      return if !env[:config_root]

      loader_env = env.merge(
        app_root: env[:config_root],
        logger: nil
      )
      loader = ModuleLoader.new(loader_env)
      if (config = loader.load(env[:mode], raise_on_missing: false))
        env[:config] = config
      end
    end

    private

    # Sets up asynchronous SIGINT handling.
    #
    # @param machine [UringMachine] machine instance
    # @param fiber [Fiber] fiber to terminate on SIGINT
    # @return [void]
    def setup_signal_handling(machine, fiber)
      queue = UM::Queue.new
      trap('SIGINT') { machine.push(queue, :SIGINT) }
      machine.spin { watch_for_int_signal(machine, queue, fiber) }
    end

    # Waits for signal from queue, then terminates the given fiber.
    #
    # @param machine [UringMachine] machine instance
    # @param queue [UringMachine::Queue] queue to wait on
    # @param fiber [Fiber] fiber to terminate
    # @return [void]
    def watch_for_int_signal(machine, queue, fiber)
      machine.shift(queue)
      machine.schedule(fiber, UM::Terminate.new)
    end
  end
end
