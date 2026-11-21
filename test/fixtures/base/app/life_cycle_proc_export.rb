export ->() { !!@fiber }

@fiber = @machine.spin do
  @machine.sleep(0)
ensure
  @fiber = nil
end

on_unload {
  @machine.terminate(@fiber)
  @machine.await(@fiber)
}
