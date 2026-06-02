# frozen_string_literal: true

require 'base64'
require 'json'
require 'securerandom'

module Syntropy
  # A Session object serves as storage for data associated with the user's
  # browser session, such as flash data (for communicating notices and alerts).
  # The session is modeled as a key-value store, where keys are strings, and
  # values can be any value that can be represented in JSON, including arrays
  # and hashes.
  #
  # The session data is stored as an HTTP cookie.
  class Session
    # Initializes the session.
    #
    # @param request [Syntropy::Request] associated request
    # @return [void]
    def initialize(request)
      @request = request
      @data = nil
    end

    # Returns the value associated with the given key.
    #
    # @param key [String]
    # @return [any] value
    def [](key)
      @data ||= load
      @data[key]
    end

    # Sets the value for the given key and updates the response session cookie.
    #
    # @param key [String]
    # @param value [any]
    # @return [void]
    def []=(key, value)
      @data ||= load
      @data[key] = value
      save(@data)
    end

    # Deletes the given key-value pair and updates the response session cookie.
    #
    # @param key [String]
    # @return [any] deleted value
    def delete(key)
      @data ||= load
      value = @data.delete(key)
      save(@data.empty? ? nil : @data)
      value
    end

    # Discards the session data, updating the response session cookie by
    # emptying it.
    #
    # @return [void]
    def discard
      save(nil)
    end

    # Returns the flash storage for the session.
    #
    # @return [Syntropy::Session::Flash]
    def flash
      @data ||= load
      @flash ||= Flash.new(self)
    end

    private

    # Loads session data from the request session cookie.
    #
    # @return [Hash] session data
    def load
      data = @request.cookies['__syntropy_session__']
      return {} if !data

      JSON.parse(Base64.decode64(data))
    rescue JSON::ParserError
      {}
    ensure
      @loaded = true
    end

    # Saves session data to the response session cookie.
    #
    # @param data [Hash] session data
    # @return [void]
    def save(data)
      cookie = data ? "#{Base64.strict_encode64(JSON.dump(data))}; Path=/; HttpOnly" : nil
      @request.set_cookie('__syntropy_session__', cookie)
    end
  end

  # NowFlash holds flash data for the current request.
  class NowFlash
    def initialize
      @data = {}
    end

    # Returns the value for the given key.
    #
    # @param key [Symbol]
    # @return [any] flash value
    def [](key)
      @data[key.to_s]
    end

    # Sets the value for the given key.
    #
    # @param key [Symbol]
    # @param value [any]
    # @return [any] value
    def []=(key, value)
      @data[key.to_s] = value
    end

    # Iterates through the flash storage, yielding each key-value pair to the
    # given block.
    #
    # @return [void]
    def each(&block)
      @data.each { |k, v| block.(k.to_sym, v) }
    end
  end

  # Flash acts as a special storage mechanism for transient information that
  # can be passsed between consecutive requests in the same session. Flash
  # values can be set in order to be retrieved in the next response. Reading
  # from flash storage will return data that was set in the previous request.
  # Data written to the flash storage will only be available to the next
  # request. You can also set flash data that will be available to the current
  # request by using Flash#now.
  #
  # In order to keep the read flash data (set in the previous request) and
  # make it available to the next request, use Flash#keep.
  class Flash
    # Initializes the flash storage.
    #
    # @return [void]
    def initialize(session)
      @session = session
      @current_flash_data = @session['_flash']
      @session.delete('_flash') if @current_flash_data
      @current_flash_data ||= {}
      @future_flash_data = {}
      @now_flash_data = NowFlash.new
    end

    # Reads data from flash storage for the given key. The value would have
    # been set in the previous request.
    #
    # @param key [Symbol]
    # @return [any] value
    def [](key)
      key = key.to_s
      @now_flash_data[key] || @current_flash_data[key]
    end

    # Sets the flash storage value for the given key. The value would be
    # available to the next request.
    #
    # @param key [Symbol]
    # @param value [any]
    # @return [void]
    def []=(key, value)
      key = key.to_s
      @future_flash_data[key] = value
      @session['_flash'] = @future_flash_data
    end

    # Iterates through the flash storage, passing each key-value pair to the
    # given block.
    #
    # @return [void]
    def each(&block)
      @current_flash_data.each_pair { |k, v| block.(k.to_sym, v) }
    end

    # Persists any flash data set in the previous request to the next request.
    #
    # @return [void]
    def keep
      @future_flash_data = @current_flash_data.merge!(@future_flash_data)
      @session['_flash'] = @future_flash_data
    end

    # Returns the flash storage for the current request.
    #
    # @return [Syntropy::NowFlash]
    def now
      @now_flash_data
    end
  end
end
