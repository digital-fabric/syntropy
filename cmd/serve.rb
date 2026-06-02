# frozen_string_literal: true

require_relative '../lib/syntropy'
require 'optparse'

env = {
  mount_path: '/',
  logger: true,
  builtin_applet_path: '/.syntropy',
  server_extensions: {
    date: true,
    name: 'Syntropy'
  }
}

parser = OptionParser.new do |o|
  o.banner = 'Usage: syntropy serve [options] DIR'

  o.on('-b', '--bind BIND', String,
       'Bind address (default: http://0.0.0.0:1234). You can specify this flag multiple times to bind to multiple addresses.') do
    env[:bind] ||= []
    env[:bind] << it
  end

  o.on('-s', '--silent', 'Silent mode') do
    env[:banner] = nil
    env[:logger] = nil
  end

  o.on('-d', '--dev', 'Development mode') do
    env[:dev_mode] = true
    env[:watch_files] = true
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

$syntropy_dev_mode = env[:dev_mode]
env[:root_dir] = (ARGV.shift || '.').gsub(/\/$/, '')

if !File.directory?(env[:root_dir])
  puts "#{File.expand_path(env[:root_dir])} Not a directory"
  exit
end

puts env[:banner] if env[:banner]
env[:banner] = false

# We set Syntropy.machine so we can reference it from anywhere
env[:machine] = Syntropy.machine = UM.new
env[:logger] = env[:logger] && Syntropy::Logger.new(env[:machine], **env)

require 'syntropy/version'
require 'syntropy/dev_mode' if env[:dev_mode]

app = Syntropy::App.load(env)
Syntropy.run(env) { app.call(it) }
