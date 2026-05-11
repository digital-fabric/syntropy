# frozen_string_literal: true

module Syntropy
  # File extension to MIME type mapping
  module MimeTypes
    TYPES = {
      'html'  => 'text/html',
      'css'   => 'text/css',
      'js'    => 'application/javascript',
      'txt'   => 'text/plain',
      'text'  => 'text/plain',
      'gif'   => 'image/gif',
      'jpg'   => 'image/jpeg',
      'jpeg'  => 'image/jpeg',
      'png'   => 'image/png',
      'ico'   => 'image/x-icon',
      'svg'   => 'image/svg+xml',
      'pdf'   => 'application/pdf',
      'json'  => 'application/json',
    }.freeze

    EXT_REGEXP = /\.?([^\.]+)$/.freeze

    def self.[](ref)
      case ref
      when Symbol
        TYPES[ref.to_s]
      when EXT_REGEXP
        TYPES[Regexp.last_match(1)]
      when ''
        nil
      else
        raise "Invalid argument #{ref.inspect}"
      end
    end
  end
end
