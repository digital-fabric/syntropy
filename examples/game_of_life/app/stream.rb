game = import '/_lib/game'
template = import '/_templates/board'

export ->(req) {
  req.validate_http_method('get')
  req.respond_sse {
    game.each_update { |board|
      req.send_ds_html_patch(template.render(board))
    }
  }
}
