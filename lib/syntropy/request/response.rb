# frozen_string_literal: true

require 'time'
require 'zlib'
require 'stringio'
require 'digest/sha1'

require_relative './status'
require_relative './mime_types'

module Syntropy
  module StaticFileCaching
    class << self
      def file_stat_to_etag(stat)
        "#{stat.mtime.to_i.to_s(36)}#{stat.size.to_s(36)}"
      end

      def file_stat_to_last_modified(stat)
        stat.mtime.httpdate
      end
    end
  end

  module ResponseMethods
    def upgrade(protocol, custom_headers = nil)
      upgrade_headers = {
        ':status' => Status::SWITCHING_PROTOCOLS,
        'Upgrade' => protocol,
        'Connection' => 'upgrade'
      }
      upgrade_headers.merge!(custom_headers) if custom_headers

      respond(nil, upgrade_headers)
    end

    WEBSOCKET_GUID = '258EAFA5-E914-47DA-95CA-C5AB0DC85B11'

    def upgrade_to_websocket(custom_headers = nil)
      key = "#{headers['sec-websocket-key']}#{WEBSOCKET_GUID}"
      upgrade_headers = {
        'Sec-WebSocket-Accept' => Digest::SHA1.base64digest(key)
      }
      upgrade_headers.merge!(custom_headers) if custom_headers
      upgrade('websocket', upgrade_headers)

      adapter.websocket_connection(self)
    end

    def redirect(url, status = Status::FOUND)
      respond(nil, ':status' => status, 'Location' => url)
    end

    def redirect_to_https(status = Status::MOVED_PERMANENTLY)
      secure_uri = "https://#{host}#{uri}"
      redirect(secure_uri, status)
    end

    def redirect_to_host(new_host, status = Status::FOUND)
      secure_uri = "//#{new_host}#{uri}"
      redirect(secure_uri, status)
    end

    def serve_file(path, opts = {})
      full_path = file_full_path(path, opts)
      stat = File.stat(full_path)
      etag = StaticFileCaching.file_stat_to_etag(stat)
      last_modified = StaticFileCaching.file_stat_to_last_modified(stat)

      if validate_static_file_cache(etag, last_modified)
        return respond(nil, {
          ':status' => Status::NOT_MODIFIED,
          'etag' => etag
        })
      end

      mime_type = Syntropy::MimeTypes[File.extname(path)]
      opts[:stat] = stat
      (opts[:headers] ||= {})['Content-Type'] ||= mime_type if mime_type

      respond_with_static_file(full_path, etag, last_modified, opts)
    rescue Errno::ENOENT
      respond(nil, ':status' => Status::NOT_FOUND)
    end

    def respond_with_static_file(path, etag, last_modified, opts)
      cache_headers = {
        'etag' => etag,
        'last-modified' => last_modified,
      }
      File.open(path, 'r') do |f|
        if opts[:headers]
          opts[:headers].merge!(cache_headers)
        else
          opts[:headers] = cache_headers
        end

        # accept_encoding should return encodings in client's order of preference
        accept_encoding.each do |encoding|
          case encoding
          when 'deflate'
            return serve_io_deflate(f, opts)
          when 'gzip'
            return serve_io_gzip(f, opts)
          end
        end
        serve_io(f, opts)
      end
    end

    def validate_static_file_cache(etag, last_modified)
      if (none_match = headers['if-none-match'])
        return true if none_match == etag
      end
      if (modified_since = headers['if-modified-since'])
        return true if modified_since == last_modified
      end

      false
    end

    def file_full_path(path, opts)
      if (base_path = opts[:base_path])
        File.join(opts[:base_path], path)
      else
        path
      end
    end

    def serve_io(io, opts)
      respond(io.read, opts[:headers] || {})
    end

    def serve_io_deflate(io, opts)
      deflate = Zlib::Deflate.new
      headers = opts[:headers].merge(
        'content-encoding' => 'deflate',
        'vary' => 'Accept-Encoding'
      )

      respond(deflate.deflate(io.read, Zlib::FINISH), headers)
    end

    def serve_io_gzip(io, opts)
      buf = StringIO.new
      z = Zlib::GzipWriter.new(buf)
      z << io.read
      z.flush
      z.close
      headers = opts[:headers].merge(
        'content-encoding' => 'gzip',
        'vary' => 'Accept-Encoding'
      )
      respond(buf.string, headers)
    end
  end
end