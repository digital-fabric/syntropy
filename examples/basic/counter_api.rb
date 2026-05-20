# frozen_string_literal: true

class CounterAPI < Syntropy::JSONAPI
  def initialize(env)
    @env = env
    @value = env[:counter_value] || 0
  end

  def value(req = nil)
    @value
  end

  def incr!(req)
    @value += 1
  end

  def decr!(req)
    @value -= 1
  end
end

export CounterAPI
