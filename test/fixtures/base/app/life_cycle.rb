export self

def loaded?
  @loaded
end

on_load { @loaded = true }
on_unload { @loaded = false }
