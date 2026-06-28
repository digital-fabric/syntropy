# frozen_string_literal: true

require 'syntropy/http/server_connection'

module Syntropy
  module HTTP
    # HTTP::Server implements an HTTP server.
    class Server
      PENDING_REQUESTS_GRACE_PERIOD = 0.1
      PENDING_REQUESTS_TIMEOUT_PERIOD = 5

      # Initializes a server instance.
      #
      # @param machine [UringMachine] machine instance
      # @param env [Hash] app environment
      # @param app [Proc, Syntropy::App] app instance
      # @return [void]
      def initialize(machine, env, &app)
        @machine = machine
        @env = env
        @app = app
        @server_fds = []
        @accept_fibers = []
      end

      # Runs the server.
      #
      # @return [void]
      def run
        setup
        @machine.await(@accept_fibers)
      rescue UM::Terminate
        graceful_shutdown
      end

      # Stops the server with graceful shutdown.
      #
      # @return [void]
      def stop!
        graceful_shutdown
      end

      private

      # Sets up the server.
      #
      # @return [void]
      def setup
        bind_info = get_bind_entries
        bind_info.each do |(host, port)|
          fd = setup_server_socket(host, port)
          @server_fds << fd
          @accept_fibers << @machine.spin { accept_incoming(fd) }
        end
        bind_string = bind_info.map { it.join(':') }.join(', ')
        @env[:logger]&.info(message: "Listening on #{bind_string}")
        setup_server_extensions

        # map fibers
        @connection_fibers = Set.new
      end

      # Returns bind entries from the app environment.
      #
      # @return [Array<Array>] array containing host/port tuples
      def get_bind_entries
        bind = @env[:bind]
        case bind
        when Array
          bind.map { bind_info(it) }
        when String
          [bind_info(bind)]
        else
          # default
          [['0.0.0.0', 1234]]
        end
      end

      # Parses a bind string into a host/port tuple.
      #
      # @param bind_string [String] bind string
      # @return [Array<String, Integer>] array containing host and port
      def bind_info(bind_string)
        parts = bind_string.split(':')
        [parts[0], parts[1].to_i]
      end

      # Sets up a TCP socket listening on the given host and port.
      #
      # @param host [String] host
      # @param port [Integer] port
      # @return [Integer] socket fd
      def setup_server_socket(host, port)
        fd = @machine.socket(UM::AF_INET, UM::SOCK_STREAM, 0, 0)
        @machine.setsockopt(fd, UM::SOL_SOCKET, UM::SO_REUSEADDR, true)
        @machine.setsockopt(fd, UM::SOL_SOCKET, UM::SO_REUSEPORT, true)
        @machine.bind(fd, host, port)
        @machine.listen(fd, UM::SOMAXCONN)
        fd
      end

      # Setup server extensions. This is used for adding additional headers to
      # the response, namely the Server the Date headers.
      #
      # @return [void]
      def setup_server_extensions
        extensions = @env[:server_extensions]
        return if !extensions

        server_name = extensions[:name]
        if extensions[:date]
          @date_header_fiber = @machine.spin {
            @machine.periodically(1) { update_server_headers(server_name) }
          }
          update_server_headers(server_name)
        elsif server_name
          @env[:server_headers] = "Server: #{server_name}\r\n"
        end
      end

      # Updates server headers.
      #
      # @param server_name [String] server name
      # @return [void]
      def update_server_headers(server_name)
        @env[:server_date] = Time.now
        if server_name
          @env[:server_headers] = "Server: #{server_name}\r\nDate: #{@env[:server_date].httpdate}\r\n"
        else
          @env[:server_headers] = "Date: #{Time.now.httpdate}\r\n"
        end
      end

      # Accepts incoming connections, spinning up a fiber for connection.
      #
      # @param listen_fd [Integer] listening socket fd
      # @return [void]
      def accept_incoming(listen_fd)
        @machine.accept_each(listen_fd) { start_connection(it) }
      rescue UM::Terminate
        @machine.shutdown(listen_fd, UM::SHUT_RD)
      end

      # Starts handling a connection on a separate fiber.
      #
      # @param fd [Integer] socket fd
      # @return [void]
      def start_connection(fd)
        conn = ServerConnection.new(@machine, fd, @env, &@app)
        f = @machine.spin(conn) do
          it.run
        ensure
          @connection_fibers.delete(f)
        end
        @connection_fibers << f
      end

      # Closes all listening socket fd's.
      #
      # @return [void]
      def close_all_server_fds
        @server_fds.each { @machine.close_async(it) }
      end

      STOP = UM::Terminate.new

      # Stops all fibers listening for incoming connections.
      #
      # @return [void]
      def stop_accept_fibers
        @accept_fibers.each { @machine.schedule(it, STOP) if !it.done? }
        @machine.await(@accept_fibers)
      end

      # Performs a graceful shutdown by stopping listening, then waiting for
      # connection fibers to stop with a timeout of 5 seconds.
      #
      # @return [void]
      def graceful_shutdown
        @env[:logger]&.info(message: 'Shutting down gracefully...')

        # stop listening
        close_all_server_fds
        stop_accept_fibers
        @machine.snooze

        return if @connection_fibers.empty?

        # sleep for a bit, let requests finish
        @machine.sleep(PENDING_REQUESTS_GRACE_PERIOD)
        return if @connection_fibers.empty?

        # terminate pending fibers
        pending = @connection_fibers.to_a
        pending.each { @machine.schedule(it, STOP) }

        @machine.timeout(PENDING_REQUESTS_TIMEOUT_PERIOD, UM::Terminate) do
          @machine.await(@connection_fibers)
        rescue UM::Terminate
          # timeout on waiting for adapters to finish running, do nothing
        end
      end
    end
  end
end
