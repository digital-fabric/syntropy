# frozen_string_literal: true

require 'bundler/setup'
require_relative './coverage' if ENV['COVERAGE']
require 'uringmachine'
require 'syntropy'
require 'qeweney/mock_adapter'
require 'minitest/autorun'
require 'fileutils'

STDOUT.sync = true
STDERR.sync = true

module ::Kernel
  def mock_req(**args)
    Qeweney::MockAdapter.mock(**args)
  end

  def capture_exception
    yield
  rescue Exception => e
    e
  end

  def debug(**h)
    k, v = h.first
    h.delete(k)

    rest = h.inject(+'') { |s, (k, v)| s << "  #{k}: #{v.inspect}\n" }
    STDOUT.orig_write("#{k}=>#{v} #{caller[0]}\n#{rest}")
  end

  def trace(*args)
    STDOUT.orig_write(format_trace(args))
  end

  def format_trace(args)
    if args.first.is_a?(String)
      if args.size > 1
        format("%s: %p\n", args.shift, args)
      else
        format("%s\n", args.first)
      end
    else
      format("%p\n", args.size == 1 ? args.first : args)
    end
  end

  def monotonic_clock
    ::Process.clock_gettime(::Process::CLOCK_MONOTONIC)
  end
end

class Minitest::Test
  def make_tmp_file_tree(dir, spec)
    FileUtils.mkdir(dir) rescue nil
    spec.each do |k, v|
      fn = File.join(dir, k.to_s)
      case v
      when String
        IO.write(fn, v)
      when Hash
        FileUtils.mkdir(fn) rescue nil
        make_tmp_file_tree(fn, v)
      end
    end
    dir
  end
end

module Minitest::Assertions
  def assert_in_range exp_range, act
    msg = message(msg) { "Expected #{mu_pp(act)} to be in range #{mu_pp(exp_range)}" }
    assert exp_range.include?(act), msg
  end

  def assert_response exp_body, exp_content_type, req
    status = req.response_status
    msg = message(msg) { "Expected HTTP status 200 OK, but instead got #{status}" }
    assert_equal 200, status, msg

    actual = req.adapter.body
    assert_equal exp_body.gsub("\n", ''), actual&.gsub("\n", '')

    return unless exp_content_type

    if Symbol === exp_content_type
      exp_content_type = Qeweney::MimeTypes[exp_content_type]
    end
    actual = req.response_content_type
    assert_equal exp_content_type, actual
  end
end

# Extensions to be used in conjunction with `Qeweney::TestAdapter`
class Qeweney::Request
  def response_headers
    adapter.headers
  end

  def response_status
    adapter.status
  end

  def response_body
    adapter.body
  end

  def response_json
    raise if response_content_type != 'application/json'
    JSON.parse(response_body, symbolize_names: true)
  end

  def response_content_type
    response_headers['Content-Type']
  end
end

# puts "Polyphony backend: #{Thread.current.backend.kind}"
