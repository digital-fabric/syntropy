layout = import('_layout/default')

export layout.apply {
  h1 'Hello from Syntropy'
  p {
    span "Here's an "
    a 'about', href: 'about'
    span ' page.'
  }
  p {
    span "Here's an "
    a 'article', href: 'articles/cage'
    span ' page.'
  }
}
