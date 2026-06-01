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
      save(@data.empty? ? nil : @data)
    end

    def discard
      save(nil)
    end

    def flash
      @data ||= load
      @flash ||= Flash.new(self)
    end

    private

    class NowFlash
      def initialize
        @data = {}
      end

      def [](key)
        @data[key.to_s]
      end

      def []=(key, value)
        @data[key.to_s] = value
      end

      def each(&block)
        @data.each { |k, v| block.(k.to_sym, v) }
      end
    end

    class Flash
      def initialize(session)
        @session = session
        @current_flash_data = @session['_flash']
        @session.delete('_flash') if @current_flash_data
        @current_flash_data ||= {}
        @future_flash_data = {}
        @now_flash_data = NowFlash.new
      end

      def [](key)
        key = key.to_s
        @now_flash_data[key] || @current_flash_data[key]
      end

      def []=(key, value)
        key = key.to_s
        @future_flash_data[key] = value
        @session['_flash'] = @future_flash_data
      end

      def each(&block)
        @now_flash_data.each { |k, v| block.(k.to_sym, v) }
        @current_flash_data.each_pair { |k, v| block.(k.to_sym, v) }
      end

      def keep
        @future_flash_data = @current_flash_data.merge!(@future_flash_data)
        @session['_flash'] = @future_flash_data
      end

      def now
        @now_flash_data
      end
    end

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
      cookie = data ? "#{Base64.strict_encode64(JSON.dump(data))}; Path=/; HttpOnly" : nil
      @request.set_cookie('__syntropy_session__', cookie)
    end
  end
end
