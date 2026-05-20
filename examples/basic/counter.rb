CounterAPI = import 'counter_api'

export template {
  html5 {
    body {
      p { a '< Home', href: '/' }

      h1 'Counter'

      div {
        button '-', id: 'decr'
        value CounterAPI.value, id: 'value'
        button '+', id: 'incr'
      }
    }
    script src: '/counter.js', type: 'module'
    style <<~CSS
      div { font-weight: bold; font-size: 1.3em }
      value { display: inline-block; padding: 0 1em; color: blue; width: 1em }
    CSS
    auto_refresh_watch!
  }
}
