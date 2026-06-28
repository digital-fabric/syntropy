# frozen_string_literal: true

require 'syntropy/errors'
require 'syntropy/http/io_extensions'

module Syntropy
  module HTTP
    # ClientConnection represents an HTTP client connection.
    class ClientConnection
      attr_reader :fd, :response_headers, :logger

      # Initializes a ClientConnection.
      #
      # @param machine [UringMachine] machine instance
      # @param fd [Integer] file descriptor
      # @param io_mode [Symbol] IO mode
      # @return [void]
      def initialize(machine, fd, io_mode: :socket)
        @machine = machine
        @fd = fd
        @io = machine.io(fd, io_mode)
      end

      # Performs a request with the given body and headers.
      #
      # @param body [String, nil] request body
      # @param headers [Hash] request headers
      # @return [Hash] response headers
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

      # Returns the response body
      #
      # @param headers [Hash] response headers
      # @return [String, nil] response body
      def get_response_body(headers)
        @io.http_read_body(headers)
      end
    end
  end
end
