game = import '/_lib/game'
template = import '/_templates/board'

@subscribers = Set.new
def each_update(&block)
  mailbox = Fiber.current.mailbox
  @subscribers << mailbox
  loop do
    html = @machine.shift(mailbox)
    yield(html)
  end
ensure
  @subscribers.delete(mailbox)
end

@machine.spin {
  game.each_update { |board|
    html = template.render(board)
    @subscribers.each { |m| @machine.push(m, html) }
  }
}

export ->(req) {
  req.auto_compress!
  req.validate_http_method('get')
  req.respond_sse {
    each_update { |html| req.send_ds_html_patch(html) }
  }
}
