# frozen_string_literal: true

require 'uri'

module Syntropy
  # Request information extension methods.
  module RequestInfoMethods
    # Returns the request host.
    #
    # @return [String, nil]
    def host
      @headers['host'] || @headers[':authority']
    end
    alias_method :authority, :host

    # Returns the connection header value.
    #
    # @return [String, nil]
    def connection
      @headers['connection']
    end

    # Returns the upgrade protocol.
    #
    # @return [String, nil]
    def upgrade_protocol
      connection == 'upgrade' && @headers['upgrade']&.downcase
    end

    # Returns the websocket version.
    #
    # @return [String, nil]
    def websocket_version
      headers['sec-websocket-version'].to_i
    end

    # Returns the protocol.
    #
    # @return [String, nil]
    def protocol
      @protocol ||= @adapter.protocol
    end

    # Returns the HTTP method in lower case.
    #
    # @return [String]
    def method
      @method ||= @headers[':method'].downcase
    end

    # Returns the request scheme.
    #
    # @return [String, nil]
    def scheme
      @scheme ||= @headers[':scheme']
    end

    # Returns the request content type.
    #
    # @return [String, nil]
    def content_type
      ct = @headers['content-type']
      return nil if !ct

      m = ct.match(/^([^;]+)/)
      return nil if !m

      m[1].strip
    end

    # Rewrites the request path by replacing the given src with the given
    # replacement.
    #
    # @param src [String, Regexp] src pattern
    # @param replacement [String] replacement
    # @return [Syntropy::Request] self
    def rewrite!(src, replacement)
      @headers[':path'] = @headers[':path']
        .gsub(src, replacement)
        .gsub('//', '/')
      @path = nil
      @uri = nil
      @full_uri = nil
      self
    end

    # Returns the parsed request URI.
    #
    # @return [URI::Generic]
    def uri
      @uri ||= URI.parse(@headers[':path'] || '')
    end

    # Returns the parsed full request URI.
    #
    # @return [URI::HTTP]
    def full_uri
      @full_uri = "#{scheme}://#{host}#{uri}"
    end

    # Returns the request path.
    #
    # @return [String]
    def path
      @path ||= uri.path
    end

    # Returns the request (unparsed) query string.
    #
    # @return [String, nil]
    def query_string
      @query_string ||= uri.query
    end

    # Returns the parsed query hash.
    #
    # @return [Hash]
    def query
      return @query if @query

      @query = (q = uri.query) ? parse_query(q) : {}
    end

    QUERY_KV_REGEXP = /([^=]+)(?:=(.*))?/

    # Converts a query string into a query hash
    #
    # @param query [String]
    # @return [Hash]
    def parse_query(query)
      query.split('&').each_with_object({}) do |kv, h|
        k, v = kv.match(QUERY_KV_REGEXP)[1..2]
        h[k] = v ? URI.decode_www_form_component(v) : true
      end
    end

    # Returns the request ID.
    #
    # @return [String, nil]
    def request_id
      @headers['x-request-id']
    end

    # Returns the forwarded for value.
    #
    # @return [String, nil]
    def forwarded_for
      @headers['x-forwarded-for']
    end

    # TODO: should return encodings in client's order of preference (and take
    # into account q weights)
    def accept_encoding
      encoding = @headers['accept-encoding']
      return [] unless encoding

      encoding.split(',').map { |i| i.strip }
    end

    # Returns the parsed cookie values.
    #
    # @return [String, nil]
    def cookies
      @cookies ||= parse_cookies(headers['cookie'])
    end

    COOKIE_RE = /^([^=]+)=(.*)$/.freeze
    SEMICOLON = ';'

    # Parses the cookie string.
    #
    # @param cookies [String]
    # @return [Hash]
    def parse_cookies(cookies)
      return {} unless cookies

      cookies.split(SEMICOLON).each_with_object({}) do |c, h|
        raise BadRequestError, 'Invalid cookie format' unless c.strip =~ COOKIE_RE

        key, value = Regexp.last_match[1..2]
        h[key] = URI.decode_www_form_component(value)
      end
    end

    # Reads the request body and returns form data.
    #
    # @return [Hash] form data
    def get_form_data
      body = read
      if !body || body.empty?
        raise Syntropy::Error.new('Missing form data', HTTP::BAD_REQUEST)
      end

      Syntropy::Request.parse_form_data(body, headers)
    rescue Syntropy::BadRequestError
      raise Syntropy::Error.new('Invalid form data', HTTP::BAD_REQUEST)
    end

    # Returns true if the user-agent is a browser.
    #
    # @return [bool]
    def browser?
      user_agent = headers['user-agent']
      user_agent && user_agent =~ /^Mozilla\//
    end

    # Returns true if the accept header includes the given MIME type
    #
    # @param mime_type [String] MIME type
    # @return [bool]
    def accept?(mime_type)
      accept = headers['accept']
      return nil if !accept

      @accept_parts ||= parse_accept_parts(accept)
      @accept_parts.include?(mime_type)
    end

    # Returns the bearer token.
    #
    # @return [String, nil]
    def auth_bearer_token
      auth = headers['authorization']
      if auth && (m = auth.match(/Bearer\s+([^\w]+)/))
        return m[1]
      end

      nil
    end

    private

    # Parses an accept string into an array of accepted MIME types.
    #
    # @param accept [string]
    # @return [Array<String>]
    def parse_accept_parts(accept)
      accept.split(',').map { it.match(/^\s*([^\s;]+)/)[1] }
    end
  end

  # Request info class methods
  module RequestInfoClassMethods
    # Parses form data into a hash
    #
    # @param body [String]
    # @param headers [Hash]
    # @return [Hash]
    def parse_form_data(body, headers)
      case (content_type = headers['content-type'])
      when /^multipart\/form\-data; boundary=([^\s]+)/
        boundary = "--#{Regexp.last_match(1)}"
        parse_multipart_form_data(body, boundary)
      when /^application\/x-www-form-urlencoded/
        parse_urlencoded_form_data(body)
      else
        raise BadRequestError, "Unsupported form data content type: #{content_type}"
      end
    end

    # Parses a multipart form body.
    #
    # @param body [String]
    # @param boundary [String]
    # @return [Hash]
    def parse_multipart_form_data(body, boundary)
      parts = body.split(boundary)
      raise BadRequestError, 'Invalid form data' if parts.size < 2
      parts.each_with_object({}) do |p, h|
        next if p.empty? || p == "--\r\n"

        # remove post-boundary \r\n
        p.slice!(0, 2)
        parse_multipart_form_data_part(p, h)
      end
    end

    # Parses a multipart form data part.
    #
    # @param body [String]
    # @param hash [Hash] output hash
    # @return [void]
    def parse_multipart_form_data_part(part, hash)
      body, headers = parse_multipart_form_data_part_headers(part)
      disposition = headers['content-disposition'] || ''

      name = (disposition =~ /name="([^"]+)"/) ? Regexp.last_match(1) : nil
      filename = (disposition =~ /filename="([^"]+)"/) ? Regexp.last_match(1) : nil

      if filename
        hash[name] = { filename: filename, content_type: headers['content-type'], data: body }
      else
        hash[name] = body
      end
    end

    # Parses a multipart form data part headers.
    #
    # @param part [String]
    # @return [Hash]
    def parse_multipart_form_data_part_headers(part)
      headers = {}
      while true
        idx = part.index("\r\n")
        break unless idx

        header = part[0, idx]
        part.slice!(0, idx + 2)
        break if header.empty?

        next unless header =~ /^([^\:]+)\:\s?(.+)$/

        headers[Regexp.last_match(1).downcase] = Regexp.last_match(2)
      end
      # remove trailing \r\n
      part.slice!(part.size - 2, 2)
      [part, headers]
    end

    PARAMETER_RE = /^([^=]+)(?:=(.*))?$/.freeze
    MAX_PARAMETER_NAME_SIZE = 256
    MAX_PARAMETER_VALUE_SIZE = 2**20 # 1MB

    # Parses a URL-encoded form.
    #
    # @param body [String]
    # @return [Hash]
    def parse_urlencoded_form_data(body)
      return {} unless body

      body.force_encoding(Encoding::UTF_8) unless body.encoding == Encoding::UTF_8
      body.split('&').each_with_object({}) do |i, m|
        raise BadRequestError, 'Invalid parameter format' unless i =~ PARAMETER_RE

        k = Regexp.last_match(1)
        raise BadRequestError, 'Invalid parameter size' if k.size > MAX_PARAMETER_NAME_SIZE

        v = Regexp.last_match(2)
        raise BadRequestError, 'Invalid parameter size' if v && v.size > MAX_PARAMETER_VALUE_SIZE

        m[URI.decode_www_form_component(k)] = v ? URI.decode_www_form_component(v) : true
      end
    end
  end
end
