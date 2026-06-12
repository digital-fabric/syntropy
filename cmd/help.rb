# frozen_string_literal: true

HELP = <<~MSG
  Usage: syntropy COMMAND [options]

  Available commands:

    console   Start an IRB session
    help      Show this message
    new       Create a new Syntropy app
    serve     Start a Syntropy server
    test      Run tests
    version   Show version information
MSG

$stdout << HELP
