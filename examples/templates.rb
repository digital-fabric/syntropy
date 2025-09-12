Card = import 'card'

export template {
  html5 {
    head {
      style {
        raw <<~CSS
          div {
            display: grid;
            grid-template-columns: 1fr 1fr;
          }
          span.foo {
            color: white;
            background-color: blue;
            padding: 1em;
          }
          span.bar {
            color: white;
            background-color: green;
            padding: 1em;
          }
        CSS
      }
    }
    body {
      p { a '< Home', href: '/' }

      h1 'Testing'

      div {
        span 'foo', class: 'foo'
        span 'bar', class: 'bar'
      }

      Card()
    }
    auto_refresh_watch!
    debug_template!
  }
}
