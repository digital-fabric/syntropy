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
      if @queue.count == 0 && @count < @max_conn
        return create_db
      end

      @machine.shift(@queue)
    end

    def checkin(db)
      @machine.push(@queue, db)
    end

    def create_db
      db = Extralite::Database.new(@fn, wal: true)
      setup_db(db)
      @count += 1
      db
    end

    def setup_db(db)
      # setup WAL, sync
      # setup concurrency stuff
    end
  end
end
