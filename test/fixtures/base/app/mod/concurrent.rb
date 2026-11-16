export self

@machine.sleep(rand(0.001..0.01))

@env[:concurrent_counter][:count] += 1

def id
  object_id
end
