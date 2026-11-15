# frozen_string_literal: true

require 'optparse'
require 'fileutils'

opts = {}

parser = OptionParser.new do |o|
  o.banner = 'Usage: syntropy new [OPTIONS] NAME'

  o.on('-y', '--yes', 'Confirm all overwrites') do
    opts[:yes] = true
  end

  o.on('-h', '--help', 'Show this help message') do
    puts o
    exit
  end
end

begin
  parser.parse!
rescue OptionParser::InvalidOption
  puts parser
  exit!(1)
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
  system("cp -rv#{opts[:yes] ? '' : 'i'} #{template_path}/* \"#{path}/\"")
  puts "Your app is ready in #{full_path}"
end
