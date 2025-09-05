# frozen_string_literal: true

# This module implements an SSE (server-sent events) route, that emits a message
# to the client when a file has been changed. The module is signalled by the
# running app whenever a file change, when in watch mode (`-w`). This route
# resides by default at `/.syntropy/auto_refresh/watch.sse`.
#
# The complementary client-side party is implemented in a small JS script
# residing by default at `/.syntropy/auto_refresh/watch.js`.

# Returns a hash holding references to queues for ongoing `watch.sse` requests.
def watchers
  @watchers ||= {}
end

# Signals a file change by pushing to all watcher queues.
def signal!
  @watchers.each_key { @machine.push(it, true) }
end

# Handles incoming requests to the `watch.sse` route. Adds a queue to the list
# of watchers, and waits for the queue to be signalled. In the absence of file
# change, a timeout occurs after one minute, and the request is terminated.
def call(req)
  queue = UM::Queue.new
  watchers[queue] = true

  req.send_headers('Content-Type' => 'text/event-stream')
  req.send_chunk("data: \n\n")
  @machine.timeout(60, Timeout::Error) do
    @machine.shift(queue)
    req.send_chunk("data: refresh\n\n")
  end
  req.send_chunk("retry: 0\n\n", done: true) rescue nil
rescue Timeout::Error
  req.send_chunk("retry: 0\n\n", done: true) rescue nil
rescue SystemCallError
  # ignore
rescue => e
  @logger&.error(
    message: 'Unexpected error encountered while serving auto refresh watcher',
    error: e
  )
  req.finish rescue nil
ensure
  watchers.delete(queue)
end

export self
