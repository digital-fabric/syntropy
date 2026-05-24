# frozen_string_literal: true

require 'syntropy/errors'

module Syntropy
  module HTTP
    module ProtocolMethods
      RE_REQUEST_LINE = /^([a-z]+)\s+([^\s]+)\s+http\/([019\.]{1,3})/i
      RE_HEADER_LINE = /^([a-z0-9-]+):\s+(.+)/i
      MAX_REQUEST_LINE_LEN = 1 << 14 # 16KB
      MAX_HEADER_LINE_LEN = 1 << 10 # 1KB
      MAX_CHUNK_SIZE_LEN = 16

      # @return [Hash] headers
      def http_read_request_headers
        line = read_line(MAX_REQUEST_LINE_LEN)
        return nil if !line

        m = line.match(RE_REQUEST_LINE)
        raise ProtocolError, 'Invalid request line' if !m

        http_version = m[3]
        raise UnsupportedHTTPVersionError, 'HTTP version not supported' if http_version != '1.1'

        headers = {
          ':method'   => m[1].downcase,
          ':path'     => m[2],
          ':protocol' => 'http/1.1'
        }

        loop do
          line = read_line(MAX_HEADER_LINE_LEN)
          break if line.nil? || line.empty?

          m = line.match(RE_HEADER_LINE)
          raise ProtocolError, "Invalid header: #{line[0..2047].inspect}" if !m

          headers[m[1].downcase] = m[2]
        end

        headers
      end

      def http_read_body(headers)
        content_length = headers['content-length']
        if content_length
          chunk = read(content_length.to_i)
          return chunk
        end

        chunked_encoding = headers['transfer-encoding']&.downcase == 'chunked'
        if chunked_encoding
          buf = +''
          while (chunk = http_read_cte_chunk(nil))
            buf << chunk
          end
          return buf
        end

        nil
      end

      def http_read_body_chunk(headers)
        content_length = headers['content-length']
        if content_length
          chunk = read(content_length.to_i)
          return chunk
        end

        chunked_encoding = headers['transfer-encoding']&.downcase == 'chunked'
        return http_read_cte_chunk(nil) if chunked_encoding

        nil
      end

      private

      def http_read_cte_chunk(buffer)
        chunk_size_str = read_line(MAX_CHUNK_SIZE_LEN)
        return nil if !chunk_size_str

        chunk_size = chunk_size_str.to_i(16)
        if chunk_size == 0
          read_line(0)
          return nil
        end

        chunk = read(chunk_size)
        read_line(0)

        buffer ? (buffer << chunk) : chunk
      end
    end
  end
end

UringMachine::IO.include(Syntropy::HTTP::ProtocolMethods)
