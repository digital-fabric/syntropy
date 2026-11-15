# frozen_string_literal: true

module Syntropy
  module Command
    green = "\e[32m"
    clear = "\e[0m"
    yellow = "\e[33m"
    
    BANNER =
      "\n"\
      "  #{green}\n"\
      "  #{green} ooo\n"\
      "  #{green}ooooo\n"\
      "  #{green} ooo vvv       #{clear}Syntropy - a web framework for Ruby\n"\
      "  #{green}  o vvvvv     #{clear}--------------------------------------\n"\
      "  #{green}  #{yellow}|#{green}  vvv o    #{clear}https://github.com/digital-fabric/syntropy\n"\
      "  #{green} :#{yellow}|#{green}:::#{yellow}|#{green}::#{yellow}|#{green}:\n"\
      "#{yellow}++++++++++++++++++++++++++++++++++++++++++++++++++++++++++#{clear}\n\n"

    # @param env [Hash]
    # @return [void]
    def self.parse_argv(env, &)
      parser = OptionParser.new(&)
      parser.parse!
    rescue OptionParser::InvalidOption
      puts parser
      exit!(1)
    end

    # @param env [Hash]
    # @return [void]
    def self.bootstrap(env)
      RubyVM::YJIT.enable rescue nil

      Syntropy.dev_mode = env[:mode] == 'development'
      env[:watch_files] ||= Syntropy.dev_mode

      # We set Syntropy.machine so we can reference it from anywhere
      env[:machine] = Syntropy.machine = UM.new
      require 'uringmachine/fiber_scheduler'
      Fiber.set_scheduler(UM::FiberScheduler.new(env[:machine]))

      env[:logger] = env[:logger] && Syntropy::Logger.new(env[:machine], **env)
    end

    # @param env [Hash]
    # @return [void]
    def self.setup_dev_mode(env)
      require 'syntropy/dev_mode'
      @main_fiber = Fiber.current
      env[:machine].spin do
        @app = app
        @env = env
        @machine = env[:machine]
        @module_loader = @app.module_loader
    
        loop do
          puts "Enter command: (c + Enter to open console, q + Enter to quit)"
          command = $stdin.gets.chomp
          case command
          when 'c'
            t = Thread.new {
              require 'irb'
              IRB.start
            }
            t.join
          when 'q'
            @machine.schedule(@main_fiber, UM::Terminate.new)
          end
        end
      end
    end
  end
end
