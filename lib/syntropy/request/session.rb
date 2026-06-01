# frozen_string_literal: true

require 'base64'
require 'json'
require 'securerandom'

module Syntropy
  class Session
    def initialize(request)
      @request = request
      @data = nil
    end

    def [](key)
      @data ||= load
      @data[key]
    end

    def []=(key, value)
      @data ||= load
      @data[key] = value
      save(@data)
    end

    def delete(key)
      @data ||= load
      @data.delete(key)
      save(@data)
    end

    def discard
      save(nil)
    end

    private

    # Loads session data from
    def load
      data = @request.cookies['__syntropy_session__']
      return {} if !data

      JSON.parse(Base64.decode64(data))
    rescue JSON::ParserError
      {}
    ensure
      @loaded = true
    end

    def save(data)
      cookie = data ? "#{Base64.strict_encode64(JSON.dump(data))}; HttpOnly" : nil
      @request.set_cookie('__syntropy_session__', cookie)
    end
  end
end
