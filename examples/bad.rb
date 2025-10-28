export template {
  div {
    markdown <<~MD
      ```ruby
      @buffer << #{foo}
      ```
    MD
  }
}.tap { puts '!' * 40; puts Papercraft.compiled_code(it.proc); puts}
