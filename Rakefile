# frozen_string_literal: true

require 'rake/clean'

task :default => :test
task :test do
  exec 'ruby test/run.rb'
end

task :release do
  require_relative './lib/syntropy/version'
  version = Syntropy::VERSION

  puts 'Building syntropy...'
  `gem build syntropy.gemspec`

  puts "Pushing syntropy #{version}..."
  `gem push syntropy-#{version}.gem`

  puts "Cleaning up..."
  `rm *.gem`
end
