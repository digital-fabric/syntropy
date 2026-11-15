# frozen_string_literal: true

require_relative '../lib/syntropy'
require_relative './_common'
require 'optparse'
require 'fileutils'

env = {
  mode:                 ENV['SYNTROPY_MODE'] || 'development',
  banner:               Syntropy::Command::BANNER,
  mount_path:           '/',
  builtin_applet_path:  '/.syntropy',
  logger:               true,
  server_extensions:    {
    date: true,
    name: 'Syntropy'
  }
}

Syntropy::Command.parse_argv(env) do |o|
  o.banner = 'Usage: syntropy serve [OPTIONS] [ROOT]'

  o.on('-b', '--bind ADDRESS', String, 'Bind address (default: 0.0.0.0:1234)') do
    (env[:bind] ||= []) << it
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

  o.on('-H', '--hot-reload', 'Hot-reload changed files') do
    env[:watch_files] = true
  end

  o.on('-s', '--silent', 'Silent mode') do
    env[:banner] = env[:logger] = nil
  end

  o.on('-v', '--version', 'Show version') do
    require 'syntropy/version'
    puts "Syntropy version #{Syntropy::VERSION}"
    exit
  end
end

Syntropy::Command.bootstrap(env)
root = File.expand_path(ARGV.shift || '.')
app = Syntropy::App.load(root, env)

if env[:banner]
  puts env[:banner]
  env[:banner] = false
end

Syntropy::Command.setup_dev_mode(env) if env[:mode] == 'development'
Syntropy.run(env) { app.call(it) }
