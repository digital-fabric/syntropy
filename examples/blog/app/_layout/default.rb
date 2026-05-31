export template { |**props|
  html {
    head {
      title "My awesome blog"
    }
    body {
      render_children(**props)
      auto_refresh!
    }
  }
}
