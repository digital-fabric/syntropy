# frozen_string_literal: true

module Syntropy
  def self.file_watch(machine, *roots, freq: 0.1, &block)
    raise 'Missing root paths' if roots.empty?

    require 'listen'

    queue = Thread::Queue.new
    listener = Listen.to(*roots) do |modified, added, removed|
      fns = (modified + added + removed).uniq
      fns.each { queue.push(it) }
    end
    listener.start

    loop do
      machine.sleep(freq) while queue.empty?
      fn = queue.shift
      block.call(fn)
    end
  rescue StandardError => e
    p e
    p e.backtrace
  ensure
    listener.stop
  end
end
