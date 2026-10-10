layout  = import '../_layout/repo'
repos   = import '../../_repos'

template = layout.apply { |title:, item:, content:, url_raw:, **props|
  p(class: 'single-file') { strong title }
  p { a 'Download raw file', href: url_raw }

  file_content {
    if item[:fn] =~ /\.(png|jpe?g|gif|svg)\z/i
      img(src: url_raw, alt: '')
    elsif item[:binary]
      p 'Binary file, not shown.'
    else
      pre {
        code {
          content.lines.each.each { span it, class: 'line' }
        }
      }
    end
  }
}

export ->(req) {
  repo = repos[req.route_params[:repo]]
  raise Error.not_found if !repo

  item = repo.get(req.rel_path)
  raise Error.not_found if !item 
  content = @machine.file_read(item[:fn]).force_encoding('UTF-8')

  title = "#{repo.name} - #{req.rel_path}"
  url_raw = File.join('/', req.route_params[:repo], 'raw', req.rel_path)

  repo_url = File.join('/', repo.name)

  req.respond_html(template.render(title:, repo:, repo_url:, item:, content:, url_raw:))
}
