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
  watch_files:          true
}

Syntropy::Command.parse_argv(env) do |o|
  o.banner = 'Usage: syntropy console [OPTIONS] [ROOT]'

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

Syntropy::Command.bootstrap(env)

root = File.expand_path(ARGV.shift || '.')
@app = Syntropy::App.load(root, env)
@env = env
@machine = env[:machine]
@module_loader = @app.module_loader

if env[:banner]
  puts env[:banner]
  env[:banner] = false
end

puts "Syntropy version #{Syntropy::VERSION}"
puts "App root: #{root}"

def import(ref)
  @module_loader.load(ref)
end

require 'irb'
IRB.start
