# frozen_string_literal: true

require 'syntropy/http/client_connection'
require 'uri'

module Syntropy
  module HTTP
    # HTTP Client class.
    class Client
      # Initializes an HTTP client.
      def initialize(machine)
        @machine = machine
      end

      # Performs a GET request.
      #
      # @param url [String] URL
      # @param headers [Hash] request headers
      # @return [Array] array containing response headers and body
      def get(url, **headers, &)
        uri = URI.parse(url)
        headers = headers.merge(
          ':method' => 'GET',
          ':path' => uri.request_uri
        )
        req(uri, **headers, &)
      end

      private

      # Performs an HTTP request, returning the response headers and body.
      #
      # @param uri [URI] request URI
      # @param headers [Hash] request headers
      # @return [Array] array containing response headers and body
      def req(uri, **headers)
        connection = make_connection(uri.scheme, uri.host, uri.port)
        response_headers = connection.req(**headers)
        if block_given?
          yield(response_headers, connection)
        else
          [response_headers, connection.get_response_body(response_headers)]
        end
      end

      # Creates an HTTP connection.
      #
      # @param _scheme [String] connection scheme
      # @param host [String] host
      # @param port [Integer] port
      # @return [Syntropy::HTTP::ClientConnection]
      def make_connection(_scheme, host, port)
        ip = (host =~ /^\d+\.\d+\.\d+\.\d+$/) ? host : @machine.resolve(host)[0]

        fd = @machine.tcp_connect(ip, port)
        Syntropy::HTTP::ClientConnection.new(@machine, fd)
      end
    end
  end
end
