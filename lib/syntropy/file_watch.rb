# frozen_string_literal: true

module Syntropy
  def self.file_watch(machine, *roots, period: 0.1, &block)
    raise 'Missing root paths' if roots.empty?

    require 'listen'

    queue = Thread::Queue.new
    listener = Listen.to(*roots) do |modified, added, removed|
      modified.each { queue.push([:modified, it]) }
      added.each    { queue.push([:added, it]) }
      removed.each  { queue.push([:removed, it]) }
    end
    listener.start

    loop do
      machine.sleep(period) while queue.empty?
      event, fn = queue.shift
      block.call(event, fn)
    end
  rescue StandardError => e
    p e
    p e.backtrace
  ensure
    listener.stop
  end
end
