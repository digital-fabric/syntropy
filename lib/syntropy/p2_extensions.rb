# frozen_string_literal: true

require 'p2'

P2.extension(
  'auto_refresh_watch!': ->(loc = '/.syntropy') {
    script(src: File.join(loc, 'auto_refresh/watch.js'))
  },
  'debug_template!': ->(loc = '/.syntropy') {
    script(src: File.join(loc, 'debug/debug.js'))
  }
)
