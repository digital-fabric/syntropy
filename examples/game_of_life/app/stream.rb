game = import '/_lib/game'
template = import '/_templates/board'

html_updates = @machine.broadcaster

@machine.spin {
  game.board_updates.each { |board|
    html_updates.broadcast(template.render(board))
  }
}

export ->(req) {
  req.validate_http_method('get')
  req.auto_compress!
  req.respond_sse {
    html_updates.each { |html| req.send_ds_html_patch(html) }
  }
}
