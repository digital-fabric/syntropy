layout = import '_layout/default'
repos   = import '../../_repos'

template = layout.apply { |repo_list:, **props|
  content {
    h2 'Repositories'
    ul {
      repo_list.each { |n, u|
        li { a n, href: u }
      }
    }
  }
}

export ->(req) {
  repo_list = repos.transform_values { |r| File.join(@ref, r.name) }
  req.respond_html(template.render(repo_list:))  
}
