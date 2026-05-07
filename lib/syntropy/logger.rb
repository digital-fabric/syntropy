# frozen_string_literal: true

require 'json'

module Syntropy
  class Logger
    def initialize(machine, fd = $stdout.fileno, **opts)
      @machine = machine
      @fd = fd
      @opts = opts
    end

    def info(o)
      call(:INFO, o)
    end

    def warn(o)
      call(:WARN, o)
    end

    def error(o)
      call(:ERROR, o)
    end

    private

    # @param level <Symbol> log level
    # @param o <Hash> hash
    def call(level, o)
      emit(make_entry(level, o))
    rescue StandardError => e
      puts 'Uncaught error while emitting log entry:'
      p e: e
      p e.backtrace
      exit
    end

    def emit(entry)
      @machine.write_async(@fd, "#{entry.to_json}\n")
    end

    def make_entry(level, o)
      if o[:request]
        make_request_entry(level, o)
      elsif o[:error]
        make_error_entry(level, o)
      else
        make_hash_entry(level, o)
      end
    end

    def make_error_entry(level, o)
      err = o[:error]
      {
        level: level.to_s,
        ts: (t = Time.now; t.to_i),
        ts_s: t.iso8601
      }
      .merge(o)
      .merge(
        error: "#{err.class}: #{err.message}",
        backtrace: err.backtrace
      )
    end

    def make_request_entry(level, o)
      request = o[:request]
      request_headers = request.headers
      response_headers = o[:response_headers]
      elapsed = request.adapter.monotonic_clock - request.start_stamp
      {
        level: level.to_s,
        ts: (t = Time.now; t.to_i),
        ts_s: t.iso8601,
        message: o[:message] || 'HTTP request done',
        client_ip: request.forwarded_for || '?',
        http_method: request_headers[':method'].upcase,
        user_agent: request_headers['user-agent'],
        uri: full_uri(request_headers),
        status: response_headers[':status'] || '200',
        elapsed: elapsed
      }
    end

    def make_hash_entry(level, hash)
      {
        level: level.to_s,
        ts: (t = Time.now; t.to_i),
        ts_s: t.iso8601
      }
      .merge(hash)
    end

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
