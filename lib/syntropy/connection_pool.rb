# frozen_string_literal: true

require 'extralite'

module Syntropy
  # ConnectionPool implements concurrent access to an SQLite database.
  class ConnectionPool
    attr_reader :count

    # Initializes the connection pool.
    #
    # @param machine [UringMachine] machine instance
    # @param fn [String] database filename
    # @param max_conn [Integer] maximum number of connections
    # @return [void]
    def initialize(machine, fn, max_conn)
      @machine = machine
      @fn = fn
      @count = 0
      @max_conn = max_conn
      @queue = UM::Queue.new
      @key = :"connection_pool_#{object_id}"
    end

    # Checks out a database connection, passing it to the given block. This
    # method is reentrant - called from the same fiber, it will yield the same
    # database connection.
    #
    # @return [Extralite::Database] database connection
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

    # Performs the given query by acquiring a database connection and running
    # the query.
    #
    # @param sql [String] SQL query
    # @return [Array<Hash>] result rows
    def query(sql, *, **, &)
      with_db { it.query(sql, *, **, &) }
    end

    # Executes the given query by acquiring a database connection and running
    # the query.
    #
    # @param sql [String] SQL query
    # @return [Integer] number of changed rows
    def execute(sql, *, **)
      with_db { it.execute(sql, *, **) }
    end

    # Closes the connection pool by removing all connections.
    #
    # @return [void]
    def close
      while @queue.count > 0
        db = @machine.shift(@queue)
        db.close
        @count -= 1
      end
    end

    private

    # Checks out a connection from the pool.
    #
    # @return [Extralite::Database] database connection
    def checkout
      return make_db_instance if @queue.count == 0 && @count < @max_conn

      @machine.shift(@queue)
    end

    # Checks in a connection to the pool.
    #
    # @param db [Extralite::Database] database connection
    # @return [void]
    def checkin(db)
      @machine.push(@queue, db)
    end

    # Creates a database connection.
    #
    # @return [Extralite::Database] database connection
    def make_db_instance
      Extralite::Database.new(@fn, wal: true).tap do
        @count += 1
        it.on_progress(mode: :at_least_once, period: 320, tick: 10) { @machine.snooze }
      end
    end
  end
end
