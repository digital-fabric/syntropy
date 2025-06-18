->(**props) {
  header {
    h1 'Foo'
  }
  content {
    emit_yield **props
  }
}
