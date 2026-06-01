# frozen_string_literal: true

require 'time'
require 'digest/sha1'

require_relative '../http/status'
require_relative '../mime_types'

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

    def redirect(url, status = HTTP::FOUND)
      respond(nil, ':status' => status, 'Location' => url)
    end

    def redirect_to_https(status = HTTP::MOVED_PERMANENTLY)
      secure_uri = "https://#{host}#{uri}"
      redirect(secure_uri, status)
    end

    def redirect_to_host(new_host, status = HTTP::FOUND)
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
          ':status' => HTTP::NOT_MODIFIED,
          'etag' => etag
        })
      end

      mime_type = MimeTypes[File.extname(path)]
      opts[:stat] = stat
      (opts[:headers] ||= {})['Content-Type'] ||= mime_type if mime_type

      respond_with_static_file(full_path, etag, last_modified, opts)
    rescue Errno::ENOENT
      respond(nil, ':status' => HTTP::NOT_FOUND)
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

    def respond_with_static_file(path, etag, last_modified, opts)
      cache_headers = (etag || last_modified) ? {
        'etag' => etag,
        'last-modified' => last_modified
      } : {}

      adapter.respond_with_static_file(self, path, opts, cache_headers)
    end

    def set_response_headers(headers)
      adapter.set_response_headers(headers)
    end

    def set_cookie(k, v)
      adapter.set_cookie(k, v)
    end

    def upgrade(protocol, custom_headers = nil, &block)
      upgrade_headers = {
        ':status' => HTTP::SWITCHING_PROTOCOLS,
        'Upgrade' => protocol,
        'Connection' => 'upgrade'
      }
      upgrade_headers.merge!(custom_headers) if custom_headers

      respond(nil, upgrade_headers)
      adapter.with_stream(&block)
    end

    # Responds according to the given map. The given map defines the responses
    # for each method. The value for each method is either an array containing
    # the body and header values to use as response, or a proc returning such an
    # array. For example:
    #
    #     req.respond_by_http_method(
    #       'head'  => [nil, headers],
    #       'get'   => -> { [IO.read(fn), headers] }
    #     )
    #
    # If the request's method is not included in the given map, an exception is
    # raised.
    #
    # @param map [Hash] hash mapping HTTP methods to responses
    # @return [void]
    def respond_by_http_method(map)
      value = map[self.method]
      raise Syntropy::Error.method_not_allowed if !value

      value = value.() if value.is_a?(Proc)
      (body, headers) = value
      respond(body, headers)
    end

    # Responds to GET requests with the given body and headers. Otherwise raises
    # an exception.
    #
    # @param body [String, nil] response body
    # @param headers [Hash] response headers
    # @return [void]
    def respond_on_get(body, headers = {})
      case self.method
      when 'head'
        respond(nil, headers)
      when 'get'
        respond(body, headers)
      else
        raise Syntropy::Error.method_not_allowed
      end
    end

    # Responds to POST requests with the given body and headers. Otherwise
    # raises an exception.
    #
    # @param body [String, nil] response body
    # @param headers [Hash] response headers
    # @return [void]
    def respond_on_post(body, headers = {})
      case self.method
      when 'head'
        respond(nil, headers)
      when 'post'
        respond(body, headers)
      else
      raise Syntropy::Error.method_not_allowed
      end
    end

    def respond_html(html, **headers)
      respond(
        html,
        'Content-Type' => 'text/html; charset=utf-8',
        **headers
      )
    end

    def respond_json(obj, **headers)
      respond(
        JSON.dump(obj),
        'Content-Type' => 'application/json; charset=utf-8',
        **headers
      )
    end

    def json_pretty_response(obj, **headers)
      respond(
        JSON.pretty_generate(obj),
        'Content-Type' => 'application/json; charset=utf-8',
        **headers
      )
    end
  end
end
