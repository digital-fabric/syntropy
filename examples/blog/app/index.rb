layout = import '_layout/default'

export layout.apply {
  div(style: 'text-align: center; font-size: 2em; font-weight: normal') {
    h1 {
      a(
        'Syntropy',
        style: 'color: #238',
        href: 'https://github.com/digital-fabric/syntropy',
        target: 'none'
      )
    }
    p {
      a 'Blog posts', href: '/posts'
    }
  }
}
