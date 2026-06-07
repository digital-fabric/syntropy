# frozen_string_literal: true

require 'syntropy/errors'
require 'syntropy/http/io_extensions'

module Syntropy
  module HTTP
    # Implements an HTTP/1.1 connection received by the Syntropy server. This
    # implementation rejects incoming HTTP/0.9 or HTTP/1.0 requests. The response
    # body is sent exclusively using chunked transfer encoding. Request bodies are
    # accepted using either fixed length (Content-Length header) or chunked
    # transfer encoding.
    class ServerConnection
      attr_reader :fd, :response_headers, :logger

      def initialize(machine, fd, env, io_mode: :socket, &app)
        @machine = machine
        @fd = fd
        @env = env
        @logger = env[:logger]
        @io = machine.io(fd, io_mode)
        @app = app

        @done = nil
        @response_headers = nil
        @response_cookies = nil
      end

      def run
        loop do
          persist = serve_request
          break if !persist
        end
      rescue UM::Terminate
        # server is terminated, do nothing
      rescue StandardError => e
        @logger&.error(
          message:  'Uncaught error while running connection',
          error:    e
        )
      ensure
        @io.clear
        @machine.close_async(@fd)
      end

      # Processes an incoming request by parsing the headers, creating a request
      # object and handing it off to the app handler. Returns true if the
      # connection should be persisted.
      def serve_request
        @done = nil
        @response_headers = nil
        @response_cookies = nil
        @closed = nil
        headers = @io.http_read_request_headers
        return false if !headers

        request = Syntropy::Request.new(headers, self)

        @app.call(request)
        persist = persist_connection?(headers)
        if persist && !headers[':body-done-reading'] && (headers['content-length'] || headers['transfer-encoding'])
          get_body(request)
        end
        persist
      rescue StandardError => e
        handle_error(request, e)
        false
      end

      # Handles an error encountered while serving a request by logging the error
      # and optionally sending an error response with the relevant HTTP status
      # code. For I/O errors, no response is sent.
      #
      # @param request [Syntropy::Request] HTTP request
      # @param err [Exception] error
      # @return [void]
      def handle_error(request, err)
        case err
        when SystemCallError
          log_error(err, 'I/O error')
          false
        when ProtocolError
          log_error(err, err.message)
          respond(request, err.message, ':status' => err.http_status)
        else
          log_error(err, 'Internal error')
          return if !request || @done

          respond(request, 'Internal server error', ':status' => INTERNAL_SERVER_ERROR)
        end
      end

      # Logs the given err and given message.
      #
      # @param err [Exception] error
      # @param message [String] error message
      # @return [void]
      def log_error(err, message)
        @logger&.error(message: "#{message}, closing connection", error: err)
      end

      def get_body(req)
        headers = req.headers
        return nil if headers[':body-done-reading']

        body = @io.http_read_body(headers)
        headers[':body-done-reading'] = true if body
        body
      end

      def get_body_chunk(req)
        headers = req.headers
        return nil if headers[':body-done-reading']

        chunk = @io.http_read_body_chunk(headers)
        headers[':body-done-reading'] = true if !chunk
        chunk
      end

      def complete?(req)
        req.headers[':body-done-reading']
      end

      # response API

      # Sets response headers before sending any response. This method is used to
      # add headers such as Set-Cookie or cache control headers to a response
      # before actually responding, specifically in middleware hooks.
      #
      # @param headers [Hash] response headers
      # @return [void]
      def set_response_headers(headers)
        @response_headers ? @response_headers.merge!(headers) : @response_headers = headers
      end

      DELETE_COOKIE = "; Expires=Thu, 01 Jan 1970 00:00:00 GMT; Path=/; Max-Age=0; HttpOnly"

      def set_cookie(key, value)
        (@response_cookies ||= {})[key] = value || DELETE_COOKIE
      end

      SEND_FLAGS = UM::MSG_NOSIGNAL | UM::MSG_WAITALL

      EMPTY_CHUNK = "0\r\n\r\n"
      EMPTY_CHUNK_LEN = EMPTY_CHUNK.bytesize

      CHUNKED_ENCODING_POSTLUDE = "\r\n#{EMPTY_CHUNK}"

      # Sends response including headers and body. Waits for the request to complete
      # if not yet completed. The body is sent using chunked transfer encoding.
      # @param request [Syntropy::Request] HTTP request
      # @param body [String] response body
      # @param headers
      def respond(request, body, headers)
        add_set_cookie_headers if @response_cookies
        headers = @response_headers.merge(headers) if @response_headers

        formatted_headers = format_headers(headers, body)
        @response_headers = headers
        if body
          chunk_prelude = "#{body.bytesize.to_s(16)}\r\n"
          @machine.sendv(@fd, formatted_headers, chunk_prelude, body, CHUNKED_ENCODING_POSTLUDE)
        else
          @machine.send(@fd, formatted_headers, formatted_headers.bytesize, SEND_FLAGS)
        end
        @logger&.info(request: request, response_headers: headers) if request
        @done = true
      end

      # Sends response headers. If empty_response is truthy, the response status
      # code will default to 204, otherwise to 200.
      # @param request [Syntropy::Request] HTTP request
      # @param headers [Hash] response headers
      # @param empty_response [boolean] whether a response body will be sent
      # @return [void]
      def send_headers(request, headers, empty_response: false)
        formatted_headers = format_headers(headers, !empty_response)
        @machine.send(@fd, formatted_headers, formatted_headers.bytesize, SEND_FLAGS)
        @response_headers = headers
      end

      # Sends a response body chunk. If no headers were sent, default headers are
      # sent using #send_headers. if the done option is true(thy), an empty chunk
      # will be sent to signal response completion to the client.
      # @param request [Syntropy::Request] HTTP request
      # @param chunk [String] response body chunk
      # @param done [boolean] whether the response is completed
      # @return [void]
      def send_chunk(request, chunk, done: false)
        data = +''
        data << "#{chunk.bytesize.to_s(16)}\r\n#{chunk}\r\n" if chunk
        data << EMPTY_CHUNK if done
        return if data.empty?

        @machine.send(@fd, data, data.bytesize, SEND_FLAGS)
        return if @done || !done

        @logger&.info(request: request, response_headers: @response_headers)
        @done = true
      end

      # Finishes the response to the current request. If no headers were sent,
      # default headers are sent using #send_headers.
      # @return [void]
      def finish(request)
        @machine.send(@fd, EMPTY_CHUNK, EMPTY_CHUNK_LEN, SEND_FLAGS)
        return if @done

        @logger&.info(request, request, response_headers: @response_headers)
        @done = true
      end

      def respond_with_static_file(req, path, env, cache_headers)
        fd = @machine.open(path, UM::O_RDONLY)
        env ||= {}
        if env[:headers]
          env[:headers].merge!(cache_headers)
        else
          env[:headers] = cache_headers
        end

        maxlen = env[:max_len] || 65_536
        buf = String.new(capacity: maxlen)
        headers_sent = nil
        loop do
          res = @machine.read(fd, buf, maxlen, 0)
          if res < maxlen && !headers_sent
            return respond(req, buf, env[:headers])
          elsif res == 0
            return finish(req)
          end

          if !headers_sent
            send_headers(req, env[:headers])
            headers_sent = true
          end
          done = res < maxlen
          send_chunk(req, buf, done: done)
          return if done
        end
      end

      def close
        return if @closed

        @closed = true
        @machine.shutdown(@fd, UM::SHUT_WR)
        @machine.close_async(@fd)
      end

      def with_stream
        yield @io, @fd
      end

      private

      RE_REQUEST_LINE = /^([a-z]+)\s+([^\s]+)\s+http\/([019\.]{1,3})/i
      RE_HEADER_LINE = /^([a-z0-9-]+):\s+(.+)/i
      MAX_REQUEST_LINE_LEN = 1 << 14 # 16KB
      MAX_HEADER_LINE_LEN = 1 << 10 # 1KB
      MAX_CHUNK_SIZE_LEN = 16

      def persist_connection?(headers)
        connection = headers['connection']&.downcase
        return connection != 'close'
      end

      INTERNAL_HEADER_REGEXP = /^:/

      # Formats response headers into an array. If empty_response is true(thy),
      # the response status code will default to 204, otherwise to 200.
      # @param headers [Hash] response headers
      # @param body [boolean] whether a response body will be sent
      # @return [String] formatted response headers
      def format_headers(headers, body)
        status = headers[':status'] || (body ? OK : NO_CONTENT)
        lines = format_status_line(body, status)
        lines << @env[:server_headers] if @env[:server_headers]
        headers.each do |k, v|
          next if k =~ INTERNAL_HEADER_REGEXP

          collect_header_lines(lines, k, v)
        end
        lines << "\r\n"
        lines
      end

      def format_status_line(body, status)
        if !body
          empty_status_line(status)
        else
          with_body_status_line(status, body)
        end
      end

      def empty_status_line(status)
        if status == 204
          +"HTTP/1.1 #{status}\r\n"
        else
          +"HTTP/1.1 #{status}\r\nContent-Length: 0\r\n"
        end
      end

      def with_body_status_line(status, body)
        +"HTTP/1.1 #{status}\r\nTransfer-Encoding: chunked\r\n"
      end

      def collect_header_lines(lines, key, value)
        if value.is_a?(Array)
          value.inject(lines) { |_, item| lines << "#{key}: #{item}\r\n" }
        else
          lines << "#{key}: #{value}\r\n"
        end
      end

      def add_set_cookie_headers
        @response_headers ||= {}
        sc = (@response_headers['Set-Cookie'] ||= [])
        @response_cookies.each { |k, v| sc << "#{k}=#{v}" }
      end
    end
  end
end
