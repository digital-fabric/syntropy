# frozen_string_literal: true

env = {}
argv_copy = ARGV.dup
case ARGV[0]
when '-w', '--watch'
  env[:watch_mode] = true
  ARGV.shift
when '-h', '--help'
  puts <<~MSG
    Usage: syntropy test [options] [minitest options]
        -w, --watch         Rerun tests on file system changes
        -h, --help          Show this help message
  MSG
  exit
end

require_relative '../lib/syntropy'
require_relative '../lib/syntropy/test'

$stdout.sync = true
$stderr.sync = true

Dir.glob("./test/test_*.rb").each { require(it) }

def watch_for_file_changes
  m = UM.new
  puts "Waiting for file changes in #{FileUtils.pwd}"
  m.file_watch(FileUtils.pwd, UM::IN_CREATE | UM::IN_DELETE | UM::IN_CLOSE_WRITE) {
    puts "Detected changes to #{it[:fn]}, restarting"
    break
  }
end

Minitest.run ARGV
if env[:watch_mode]
  puts
  watch_for_file_changes
  exec("ruby", __FILE__, *argv_copy)
end
