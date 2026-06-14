# frozen_string_literal: true

require_relative '../lib/syntropy'
require 'optparse'
require 'fileutils'

env = {
  app_root:             File.join(FileUtils.pwd, 'app'),
  config_root:          File.join(FileUtils.pwd, 'config'),
  mode:                 ENV['SYNTROPY_MODE'] || 'development',
  mount_path:           '/',
  builtin_applet_path:  '/.syntropy',
  logger:               true,
  watch_files:          true
}

parser = OptionParser.new do |o|
  o.banner = 'Usage: syntropy console [options]'

  o.on('-a', '--app PATH', 'Set app directory (default: ./app)') do |path|
    env[:app_root] = path
  end

  o.on('-c', '--config PATH', 'Set config directory (default: ./config)') do |path|
    env[:config_root] = path
  end

  o.on('-h', '--help', 'Show this help message') do
    puts o
    exit
  end

  o.on('-m', '--mount PATH', 'Set mount path (default: /)') do |path|
    env[:mount_path] = path
    env[:builtin_applet_path] = File.join(path, '.syntropy')
  end

  o.on('--no-builtin-applet', 'Do not mount builtin applet') do
    env[:builtin_applet_path] = nil
  end
end

RubyVM::YJIT.enable rescue nil

begin
  parser.parse!
rescue OptionParser::InvalidOption
  puts parser
  exit
rescue StandardError => e
  p e
  puts e.message
  puts e.backtrace.join("\n")
  exit
end

Syntropy.dev_mode = env[:mode] == 'development'
Syntropy.load_config(env)

if !File.directory?(env[:app_root])
  puts "#{File.expand_path(env[:app_root])} Not a directory"
  exit
end

puts env[:banner] if env[:banner]
env[:banner] = false

# We set Syntropy.machine so we can reference it from anywhere
env[:machine] = Syntropy.machine = UM.new
env[:logger] = env[:logger] && Syntropy::Logger.new(env[:machine], **env)

@app = Syntropy::App.load(env)
@env = env
@machine = env[:machine]
@connection_pool = @app.connection_pool if @app.respond_to?(:connection_pool)
@schema = @app.schema if @app.respond_to?(:schema)
@module_loader = @app.module_loader

require 'uringmachine/fiber_scheduler'
@scheduler = UM::FiberScheduler.new(@machine)
Fiber.set_scheduler(@scheduler)

def import(ref)
  @module_loader.load(ref)
end

require 'irb'
IRB.start
