layout  = import '../_layout/repo'
repos   = import '../../_repos'

template = layout.apply { |commits:, **props|
  commits {
    ul {
      commits.each {
        li it
      }
    }
  }
}

export ->(req) {
  repo = repos[req.route_params[:repo]]
  raise Error.not_found if !repo

  commits = repo.commits[0..15]
  title = repo.name
  repo_url = File.join('/', repo.name)

  req.respond_html(template.render(title:, repo:, repo_url:, commits:))
}
