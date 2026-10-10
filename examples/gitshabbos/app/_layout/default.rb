export template { |**props|
  html {
    head {
      title "Gitshabbos - #{props[:title]}"
      meta charset: 'utf-8'
      meta name: 'viewport', content: 'width=device-width, initial-scale=1.0'
      link rel: "stylesheet", type: "text/css", href: "/assets/style.css"
    }
    body {
      render_children(**props)
      auto_refresh!
    }
  }
}
