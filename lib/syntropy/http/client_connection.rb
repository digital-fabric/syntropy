# frozen_string_literal: true

require 'syntropy/errors'
require 'syntropy/http/io_extensions'

module Syntropy
  module HTTP
    class ClientConnection
      attr_reader :fd, :response_headers, :logger

      def initialize(machine, fd, io_mode: :socket)
        @machine = machine
        @fd = fd
        @io = machine.io(fd, io_mode)
      end

      def req(body: nil, **headers)
        if body
          headers = headers.merge(
            'Content-Length' => body.bytesize
          )
        end
        @io.http_write_request_headers(**headers)
        if body
          @io.write(body)
        end

        @io.http_read_response_headers
      end

      def get_response_body(headers)
        @io.http_read_body(headers)
      end
    end
  end
end
