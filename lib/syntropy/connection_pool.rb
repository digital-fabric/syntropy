# frozen_string_literal: true

require 'extralite'

module Syntropy
  class ConnectionPool
    attr_reader :count

    def initialize(machine, fn, max_conn)
      @machine = machine
      @fn = fn
      @count = 0
      @max_conn = max_conn
      @queue = UM::Queue.new
      @key = :"db_#{fn}"
    end

    def with_db
      if (db = Thread.current[@key])
        @machine.snooze
        return yield(db)
      end

      db = checkout
      begin
        Thread.current[@key] = db
        yield(db)
      ensure
        Thread.current[@key] = nil
        checkin(db)
      end
    end

    private

    def checkout
      return make_db_instance if @queue.count == 0 && @count < @max_conn

      @machine.shift(@queue)
    end

    def checkin(db)
      @machine.push(@queue, db)
    end

    def make_db_instance
      Extralite::Database.new(@fn, wal: true).tap do
        @count += 1
        it.on_progress(mode: :at_least_once, period: 320, tick: 10) { @machine.snooze }
      end
    end
  end
end
