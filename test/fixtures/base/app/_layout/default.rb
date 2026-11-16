export template { |**props|
  header {
    h1 'Foo'
  }
  content {
    render_children(**props)
  }
}
