# frozen_string_literal: true

require_relative '../lib/syntropy'
require 'optparse'
require 'fileutils'

env = {
  app_path:             File.join(FileUtils.pwd, 'app'),
  config_path:          File.join(FileUtils.pwd, 'config'),
  mode:                 ENV['SYNTROPY_MODE'] || 'development',
  mount_path:           '/',
  builtin_applet_path:  '/.syntropy',
  logger:               true,
  server_extensions:    {
    date: true,
    name: 'Syntropy'
  }
}

parser = OptionParser.new do |o|
  o.banner = 'Usage: syntropy serve [options]'

  o.on('-a', '--app PATH', 'Set app directory (default: ./app') do |path|
    env[:app_path] = path
  end

  o.on('-b', '--bind BIND', String,
       'Bind address (default: http://0.0.0.0:1234). You can specify this flag multiple times to bind to multiple addresses.') do
    env[:bind] ||= []
    env[:bind] << it
  end

  o.on('-c', '--config PATH', 'Set config directory (default: ./config') do |path|
    env[:config_path] = path
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

  o.on('--no-server-headers', 'Don\'t include Server and Date headers') do
    env[:server_extensions] = nil
  end

  o.on('-s', '--silent', 'Silent mode') do
    env[:banner] = nil
    env[:logger] = nil
  end

  o.on('-v', '--version', 'Show version') do
    require 'syntropy/version'
    puts "Syntropy version #{Syntropy::VERSION}"
    exit
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
env[:watch_files] = Syntropy.dev_mode

if !File.directory?(env[:app_path])
  puts "#{File.expand_path(env[:app_path])} Not a directory"
  exit
end

puts env[:banner] if env[:banner]
env[:banner] = false

# We set Syntropy.machine so we can reference it from anywhere
env[:machine] = Syntropy.machine = UM.new
env[:logger] = env[:logger] && Syntropy::Logger.new(env[:machine], **env)

require 'syntropy/version'
require 'syntropy/dev_mode' if Syntropy.dev_mode

app = Syntropy::App.load(env)
Syntropy.run(env) { app.call(it) }
