# frozen_string_literal: true

require_relative './_common'
require 'fileutils'
require 'optparse'

pwd = FileUtils.pwd
env = {
  mode:                 'test',
  mount_path:           '/'
}
MINITEST_ARGV = []

argv_copy = ARGV.dup
Syntropy::Command.parse_argv(env) do |o|
  o.banner = 'Usage: syntropy test [OPTIONS] [ROOT]'

  o.on('-h', '--help', 'Show this help message') do
    puts o
    exit
  end

  o.on('-f', '--file PATH', 'Set test file') do |path|
    env[:test_file] = path
  end

  o.on('-m', '--mount PATH', 'Set mount path (default: /)') do |path|
    env[:mount_path] = path
    env[:builtin_applet_path] = File.join(path, '.syntropy')
  end

  o.on('-n', '--name NAME', 'Specify test to run') do |name|
    MINITEST_ARGV << '--name' << name
  end

  o.on('-s', '--seed SEED', 'Specify random seed') do |seed|
    MINITEST_ARGV << '--seed' << seed
  end

  o.on('-t', '--test PATH', 'Set test directory (default: ./test)') do |path|
    env[:test_root] = path
  end

  o.on('-V', '--verbose', 'Verbose test output') do
    MINITEST_ARGV << '--verbose'
  end

  o.on('-v', '--version', 'Show version') do
    require 'syntropy/version'
    puts "Syntropy version #{Syntropy::VERSION}"
    exit
  end

  o.on('-w', '--watch', 'Watch for file changes') do
    env[:watch_mode] = true
  end
end

require_relative '../lib/syntropy'
require_relative '../lib/syntropy/test'

$stdout.sync = true
$stderr.sync = true

root = File.expand_path(ARGV.shift || '.')
env = Syntropy::App.setup_env(root, env)

if env[:test_file]
  require(File.expand_path(env[:test_file]))
else
  Dir.glob("#{File.expand_path(env[:test_root])}/test_*.rb").each { require(it) }
end

def restart_on_file_change(machine, dir, restart_argv)
  machine.file_watch(dir, UM::IN_CREATE | UM::IN_DELETE | UM::IN_CLOSE_WRITE) {
    machine.write(UM::STDOUT_FILENO, "File changed: #{it[:fn]}\n")
    break
  }
  exec('ruby', __FILE__, *restart_argv)
end

puts "Syntropy version #{Syntropy::VERSION}"
puts "App root: #{root}"

Syntropy::Test.global_env = env
Minitest.run MINITEST_ARGV

if env[:watch_mode]
  m = UM.new(size: 4)
  m.write(UM::STDOUT_FILENO, "\n")
  trap('SIGINT') { m.write(UM::STDOUT_FILENO, "\n"); exit! }

  m.write(UM::STDOUT_FILENO, "Waiting for file changes...\n")
  m.join(
    m.spin { restart_on_file_change(m, env[:app_root], argv_copy) },
    m.spin { restart_on_file_change(m, env[:test_root], argv_copy) }
  )
end
