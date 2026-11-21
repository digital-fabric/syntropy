export self

def loaded?
  @loaded
end

@loaded = true
on_unload { @loaded = false }
