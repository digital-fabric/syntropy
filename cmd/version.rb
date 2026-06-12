# frozen_string_literal: true

require 'syntropy/version'
require 'uringmachine/version'
require_relative './_banner'

VERSION = <<~MSG
      Syntropy version #{Syntropy::VERSION}
  UringMachine version #{UringMachine::VERSION}
          Ruby version #{RUBY_VERSION}
MSG

$stdout << SYNTROPY_BANNER
$stdout << VERSION
