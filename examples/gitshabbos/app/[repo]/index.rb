layout  = import '../_layout/repo'
repos   = import '../../_repos'

template = layout.apply { |md:, files:, **props|
  main {
    markdown(md)
  }
  sidebar {
    ul {
      files.each { |r, u|
        li { a r, href: u }
      }
    }
  }
}

export ->(req) {
  repo = repos[req.route_params[:repo]]
  raise Error.not_found if !repo
  
  item = repo.get('README.md')
  md = item ? @machine.file_read(item[:fn]).force_encoding('UTF-8') : ''

  files = repo.list.each_with_object({}) { |r, h|
    h[r[:ref]] = File.join(req.path, 'tree', r[:ref])
  }.sort_by { |k, v| k }

  title = repo.name
  repo_url = req.path

  req.respond_html(template.render(title:, repo:, repo_url:, md:, files:))
}
