# frozen_string_literal: true

TAG_DEBUG_PROC = ->(level, fn, line, col) {
  {
    'data-syntropy-level' => level,
    'data-syntropy-fn'    => fn,
    'data-syntropy-loc'   => "vscode://file/#{fn}:#{line}:#{col}"
  }
}

Papercraft::Compiler.html_debug_attribute_injector = TAG_DEBUG_PROC
