# frozen_string_literal: true

require 'etc'

module Syntropy
  # SideRun implements running an operation on a separate thread.
  module SideRun
    class << self
      # Runs the given block on a separate thread, using UringMachine to wait
      # for the operation to complete. If the operation results in a raised
      # exception, that exception will be reraised in the context of the waiting
      # fiber.
      #
      # @param machine [UringMachine] machine instance
      # @return [any] operation return value
      def call(machine, &block)
        setup if !@queue

        # TODO: share mailboxes, acquire them with e.g. with_mailbox { |mbox| ... }
        mailbox = Thread.current[:fiber_mailbox] ||= UM::Queue.new
        machine.push(@queue, [mailbox, block])
        result = machine.shift(mailbox)
        result.is_a?(Exception) ? (raise result) : result
      end

      private

      # Sets up a thread pool for side-running operations.
      #
      # @return [void]
      def setup
        @queue = UM::Queue.new
        count = (Etc.nprocessors - 1).clamp(2..6)
        @workers = count.times.map {
          Thread.new { side_run_worker(@queue) }
        }
      end

      # Runs worker loop for running side-run operations.
      #
      # @param queue [UringMachine::Queue] queue for pulling operations
      # @return [void]
      def side_run_worker(queue)
        machine = UM.new
        loop { run_op(machine, queue) }
      rescue UM::Terminate
        # # We can also add a timeout here
        # t0 = Time.now
        # while !queue.empty? && (Time.now - t0) < 10
        #   handle_request(machine, queue)
        # end
      end

      # Pulls an operation from the given queue and runs it, pushing its return
      # value to the corresponding mailbox.
      #
      # @param machine [UringMachine] machine instance
      # @param queue [UringMachine::Queue] op queue
      # @return [void]
      def run_op(machine, queue)
        response_mailbox, closure = machine.shift(queue)
        result = closure.call
        machine.push(response_mailbox, result)
      rescue Exception => e
        machine.push(response_mailbox, e)
      end
    end
  end
end
