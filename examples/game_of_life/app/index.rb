game = import '/_lib/game'
board_template = import '/_templates/board'

layout = template { |board|
  html {
    head {
      title "Game Of Life"
      link(
        rel: 'stylesheet',
        type: 'text/css',
        href: '/assets/style.css'
      )
      script(type: 'module', src: "https://cdn.jsdelivr.net/gh/starfederation/datastar@v1.0.4/bundles/datastar.js")
    }
    body(data_init: "@get('/stream')") {
      div(id: 'container', ) {
        markdown <<~MD
          # Multiplayer Game of Life

          Made using [Syntropy](https://github.com/digital-fabric/syntropy) and
          [Datastar](https://data-star.dev/)

          [Source](https://github.com/noteflakes/noteflakes.com/tree/main/sites/noteflakes.com/app) -
          [Original idea](https://example.andersmurphy.com/)
        MD

        render board_template, board
      }
      auto_refresh!
    }
  }
}

colors = %w{black red blue green orange fuchsia purple}

export ->(req) {
  req.session['game_color'] = colors.sample
  req.validate_http_method('get')
  board = game.board
  req.respond_html(layout.render(board))
}
