# frozen_string_literal: true

require 'etc'

module Syntropy
  module SideRun
    class << self
      def call(machine, &block)
        setup if !@queue

        # TODO: share mailboxes, acquire them with e.g. with_mailbox { |mbox| ... }
        mailbox = Thread.current[:fiber_mailbox] ||= UM::Queue.new
        machine.push(@queue, [mailbox, block])
        result = machine.shift(mailbox)
        result.is_a?(Exception) ? (raise result) : result
      end

      def setup
        @queue = UM::Queue.new
        count = (Etc.nprocessors - 1).clamp(2..6)
        @workers = count.times.map {
          Thread.new { side_run_worker(@queue) }
        }
      end

      def side_run_worker(queue)
        machine = UM.new
        loop { handle_request(machine, queue) }
      rescue UM::Terminate
        # # We can also add a timeout here
        # t0 = Time.now
        # while !queue.empty? && (Time.now - t0) < 10
        #   handle_request(machine, queue)
        # end
      end

      def handle_request(machine, queue)
        response_mailbox, closure = machine.shift(queue)
        result = closure.call
        machine.push(response_mailbox, result)
      rescue Exception => e
        machine.push(response_mailbox, e)
      end
    end
  end
end
