# frozen_string_literal: true

require 'syntropy/http/client_connection'
require 'uri'

module Syntropy
  module HTTP
    # HTTP Client class.
    class Client
      def initialize(machine)
        @machine = machine
      end

      def get(url, **headers, &)
        uri = URI.parse(url)
        headers = headers.merge(
          ':method' => 'GET',
          ':path' => uri.request_uri
        )
        req(uri, **headers, &)
      end

      private

      # @param uri [URI]
      def req(uri, **headers)
        connection = make_connection(uri.scheme, uri.host, uri.port)
        response_headers = connection.req(**headers)
        if block_given?
          yield(response_headers, connection)
        else
          [response_headers, connection.get_response_body(response_headers)]
        end
      end

      def make_connection(_scheme, host, port)
        ip = (host =~ /^\d+\.\d+\.\d+\.\d+$/) ? host : @machine.resolve(host)[0]

        fd = @machine.tcp_connect(ip, port)
        Syntropy::HTTP::ClientConnection.new(@machine, fd)
      end
    end
  end
end
