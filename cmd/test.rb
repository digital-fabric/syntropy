# frozen_string_literal: true

require 'fileutils'
require 'optparse'

pwd = FileUtils.pwd
env = {
  root_dir: File.join(pwd, 'app'),
  test_dir: File.join(pwd, 'test'),
  mount_path: '/'
}
MINITEST_ARGV = []

parser = OptionParser.new do |o|
  o.banner = 'Usage: syntropy test [options]'

  o.on('-h', '--help', 'Show this help message') do
    puts o
    exit
  end

  o.on('-m', '--mount PATH', 'Set mount path (default: /)') do |path|
    env[:mount_path] = path
    env[:builtin_applet_path] = File.join(path, '.syntropy')
  end

  o.on('-w', '--watch', 'Watch for file changes') do
    env[:watch_mode] = true
  end

  o.on('-a', '--app PATH', 'Set app root (default: ./app)') do |path|
    env[:root_dir] = path
  end

  o.on('-t', '--test PATH', 'Set test root (default: ./test)') do |path|
    env[:test_dir] = path
  end

  o.on('-n', '--name NAME', 'Specify test to run') do |name|
    MINITEST_ARGV << '--name' << name
  end

  o.on('-V', '--verbose', 'Verbose test output') do
    MINITEST_ARGV << '--verbose'
  end

  o.on('-s', '--seed SEED', 'Specify random seed') do |seed|
    MINITEST_ARGV << '--seed' << seed
  end

  o.on('-v', '--version', 'Show version') do
    require 'syntropy/version'
    puts "Syntropy version #{Syntropy::VERSION}"
    exit
  end
end

argv_copy = ARGV.dup
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

require_relative '../lib/syntropy'
require_relative '../lib/syntropy/test'

$stdout.sync = true
$stderr.sync = true

Dir.glob("#{env[:test_dir]}/test_*.rb").each { require(it) }

def watch_for_file_changes(machine)
  machine.write(UM::STDOUT_FILENO, "Waiting for file changes in #{FileUtils.pwd}\n")
  machine.file_watch(FileUtils.pwd, UM::IN_CREATE | UM::IN_DELETE | UM::IN_CLOSE_WRITE) {
    machine.write(UM::STDOUT_FILENO, "File changed: #{it[:fn]}\n")
    break
  }
end

Syntropy::Test.env = (env)
Minitest.run MINITEST_ARGV

if env[:watch_mode]
  m = UM.new(size: 4)
  m.write(UM::STDOUT_FILENO, "\n")
  trap('SIGINT') { m.write(UM::STDOUT_FILENO, "\n"); exit! }
  watch_for_file_changes(m)
  exec("ruby", __FILE__, *argv_copy)
end
