export templ { |*a, **b|
  html {
    head {
      title 'My awesome Syntropy website'
      link rel: 'stylesheet', type: 'text/css', href: '/assets/css/style.css'
    }
    body {
      emit_yield(*a, **b)
    }
  }
}
