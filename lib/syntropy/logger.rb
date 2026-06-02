# frozen_string_literal: true

require 'json'

module Syntropy
  # The Logger class implements a logger with support for structured logging.
  class Logger
    # Initializes the logger.
    #
    # @param machine [UringMachine] machine instance
    # @param fd [Integer] file descriptor for writing log messages
    # @param opts [Hash] logger options
    # @return [void]
    def initialize(machine, fd = $stdout.fileno, **opts)
      @machine = machine
      @fd = fd
      @opts = opts
    end

    # Logs an INFO entry.
    #
    # @param o [Hash] log entry
    # @return [void]
    def info(o)
      call(:INFO, o)
    end

    # Logs an WARN entry.
    #
    # @param o [Hash] log entry
    # @return [void]
    def warn(o)
      call(:WARN, o)
    end

    # Logs an ERROR entry.
    #
    # @param o [Hash] log entry
    # @return [void]
    def error(o)
      call(:ERROR, o)
    end

    private

    # Writes a log entry.
    #
    # @param level [Symbol] log level
    # @param o [Hash] entry
    # @return [void]
    def call(level, o)
      emit(make_entry(level, o))
    rescue StandardError => e
      puts 'Uncaught error while emitting log entry:'
      p e: e
      p e.backtrace
      exit
    end

    # Emits an entry to the associated output.
    #
    # @param entry [Hash] log entry
    # @return [void]
    def emit(entry)
      @machine.write_async(@fd, "#{entry.to_json}\n")
    end

    # Transforms raw entry into a log entry. Additional information is added
    # dependending on the kind of entry.
    #
    # @param level [Symbol] log level
    # @param o [Hash] raw entry
    # @return [Hash] log entry
    def make_entry(level, o)
      if o[:request]
        make_request_entry(level, o)
      elsif o[:error]
        make_error_entry(level, o)
      else
        make_hash_entry(level, o)
      end
    end

    # Makes an error log entry.
    #
    # @param level [Symbol] log level
    # @param o [Hash] input entry
    # @return [Hash] output entry
    def make_error_entry(level, o)
      err = o[:error]
      t = Time.now
      {
        level:  level.to_s,
        ts:     t.to_i,
        ts_s:   t.iso8601
      }.merge(o).merge(
        error: "#{err.class}: #{err.message}",
        backtrace: err.backtrace
      )
    end

    # Makes a request log entry.
    #
    # @param level [Symbol] log level
    # @param o [Hash] input entry
    # @return [Hash] output entry
    def make_request_entry(level, o)
      request = o[:request]
      request_headers = request.headers
      response_headers = o[:response_headers]
      elapsed = monotonic_clock - request.start_stamp
      t = Time.now
      {
        level:        level.to_s,
        ts:           t.to_i,
        ts_s:         t.iso8601,
        message:      o[:message] || 'HTTP request done',
        client_ip:    request.forwarded_for || '?',
        http_method:  request_headers[':method'].upcase,
        user_agent:   request_headers['user-agent'],
        uri:          full_uri(request_headers),
        status:       response_headers[':status'] || '200',
        elapsed:      elapsed
      }
    end

    # Makes a request log entry.
    #
    # @param level [Symbol] log level
    # @param o [Hash] input entry
    # @return [Hash] output entry
    def make_hash_entry(level, hash)
      t = Time.now
      {
        level:  level.to_s,
        ts:     t.to_i,
        ts_s:   t.iso8601
      }.merge(hash)
    end

    # Returns the monotonic clock.
    #
    # @return [Float]
    def monotonic_clock
      ::Process.clock_gettime(::Process::CLOCK_MONOTONIC)
    end

    # Returns the full request URI for the given request headers.
    #
    # @param headers [Hash] request headers
    # @return [String] request URI
    def full_uri(headers)
      format(
        '%<scheme>s://%<host>s%<path>s',
        scheme: headers['x_forwarded_proto'] || 'http',
        host:   headers['host'],
        path:   headers[':path']
      )
    end
  end
end
