# frozen_string_literal: true

module Syntropy
  # The MimeTypes module maps file extensions to MIME types.
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

    # Returns the mime type for the given file extension.
    #
    # @param ext [String, Symbol] file extension
    # @return [String, nil] MIME type
    def self.[](ext)
      case ext
      when Symbol
        TYPES[ext.to_s]
      when EXT_REGEXP
        TYPES[Regexp.last_match(1)]
      when ''
        nil
      else
        raise "Invalid argument #{ext.inspect}"
      end
    end
  end
end
