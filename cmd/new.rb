# frozen_string_literal: true

require 'optparse'
require 'fileutils'

parser = OptionParser.new do |o|
  o.banner = 'Usage: syntropy new NAME [options]'

  o.on('-h', '--help', 'Show this help message') do
    puts o
    exit
  end
end

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

path = ARGV.shift
if !path
  $stdout <<  'Please enter a name for your app: '
  path = $stdin.gets
end

full_path = File.expand_path(path)
puts "Creating app in #{full_path}"

template_path = File.join(__dir__, 'new/template')

begin
  `mkdir -p "#{path}"`
  `cp -r #{template_path}/* "#{path}/"`
  puts "Your app is ready in #{path}"
rescue => e
  p e
  p e.backtrace
  exit(1)
end
