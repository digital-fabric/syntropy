# frozen_string_literal: true

# Injects debug information into Papercraft emitted HTML tags.
#
# @param level [Integer] nesting level
# @param fn [String] source filename
# @param line [Integer] source line
# @param col [Integer] source column
# @return [Hash] HTML data attributes
Papercraft::Compiler.html_debug_attribute_injector = ->(level, fn, line, col) {
  {
    'data-syntropy-level' => level,
    'data-syntropy-fn'    => fn,
    'data-syntropy-loc'   => "zed://file/#{fn}:#{line}:#{col}"
  }
}
