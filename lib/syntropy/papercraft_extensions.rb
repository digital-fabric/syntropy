# frozen_string_literal: true

require 'papercraft'

Papercraft.extension(
  'auto_refresh!': ->(loc = '/.syntropy') {
    if Syntropy.dev_mode
      script(src: File.join(loc, 'auto_refresh/watch.js'), type: 'module')
    end
  },
  'debug_template!': ->(loc = '/.syntropy') {
    if Syntropy.dev_mode
      script(src: File.join(loc, 'debug/debug.js'), type: 'module')
    end
  }
)
