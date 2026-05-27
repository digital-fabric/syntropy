export self

require 'securerandom'

@store = {}

def store(params)
  key = SecureRandom.hex(16)
  @store[key] = params
  key
end

def retrieve(key)
  @store[key]
end
