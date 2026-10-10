default = import './default'

export default.apply { |repo:, **props|
  nav {
    a '← index', href: '/'
    text ' | '
    a 'about', href: props[:repo_url]
    text ' | '
    a 'commits', href: File.join(props[:repo_url], 'commits')
  }
  if props[:header] != false
    header {
      h3 repo.name
      p repo.description
      p { code "git clone https://git.noteflakes.com/#{repo.name}/.git" }
    }
  end
  content {
    render_children(**props)
  }
  footer {
    p {
      text 'Powered by '
      a 'Syntropy', href: 'https://github.com/digital-fabric/syntropy'
    }
  }
}
