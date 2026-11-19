game = import '/_lib/game'

IDX_RANGE = 0...(game.size ** 2)

export ->(req) {
  req.validate_http_method('post')
  idx = req.validate_param('idx', Integer, IDX_RANGE)
  color = req.session['game_color']
  game.fill_cross(idx, req.session['game_color'])
  req.respond(nil)
}
