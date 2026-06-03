layout = import '_layout/default'

require 'papercraft/version'

export layout.apply {
  div(style: 'text-align: center; font-size: 2em; font-weight: bold; margin-bottom: 0.5em') {
    h1 {
      a(
        'Syntropy',
        style: 'color: #238',
        href: 'https://github.com/digital-fabric/syntropy',
        target: 'none'
      )
    }
  }
  div(style: 'text-align: center') {
    p {
      a 'Test page', href: '/test'
    }
    div(style: 'font-size: 0.8em; margin-top: 1em') {
      div { span 'Syntropy version: '; span Syntropy::VERSION }
      div { span 'Papercraft version: '; span Papercraft::VERSION }
      div { span 'UringMachine version: '; span UM::VERSION }
      div { span 'Ruby version: '; span RUBY_VERSION }
    }
  }
}
