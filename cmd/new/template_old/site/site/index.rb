layout = import('_layout/default')

export Papercraft.apply(layout) {
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
