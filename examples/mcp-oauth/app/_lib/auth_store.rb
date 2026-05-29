export self

require 'securerandom'

@store = {}

def store(params)
  key = SecureRandom.hex(16)
  @store[key] = params
  key
end

def fetch(key)
  @store[key]
end

def update(key, value)
  @store[key] = value
end

def fetch_and_remove(key)
  @store.delete(key)
end
