# frozen_string_literal: true

require 'syntropy/http/client_connection'
require 'uri'
require 'openssl'

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
        headers = headers.merge('Host' => uri.host) if !headers['Host']

        response_headers = connection.req(**headers)
        if block_given?
          yield(response_headers, connection)
        else
          [response_headers, connection.get_response_body(response_headers)]
        end
      end

      # Creates an HTTP connection.
      #
      # @param scheme [String] connection scheme
      # @param host [String] host
      # @param port [Integer] port
      # @return [Syntropy::HTTP::ClientConnection]
      def make_connection(scheme, host, port)
        ip = (host =~ /^\d+\.\d+\.\d+\.\d+$/) ? host : @machine.resolve(host)[0]
        fd = @machine.tcp_connect(ip, port)

        if scheme == 'https'
          https_client_connection(fd, host)
        else
          Syntropy::HTTP::ClientConnection.new(@machine, fd)
        end
      end

      # Creates and returns an HTTPS connection for the given fd. Verifies the
      # host for the SSL connection.
      #
      # @param fd [Integer]
      # @param host [String]
      # @return [Syntropy::HTTP::ClientConnection]
      def https_client_connection(fd, host)
        ssl = OpenSSL::SSL::SSLSocket.new(IO.for_fd(fd), OpenSSL::SSL::SSLContext.new)
        ssl.hostname = host
        ssl.sync_close = true
        ssl.connect
        ssl.post_connection_check(host)
        @machine.ssl_set_bio(ssl)

        Syntropy::HTTP::ClientConnection.new(@machine, ssl, io_mode: :ssl)
      end
    end
  end
end
