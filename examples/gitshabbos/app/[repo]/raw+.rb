repos   = import '../../_repos'

export ->(req) {
  repo = repos[req.route_params[:repo]]
  raise Error.not_found if !repo

  item = repo.get(req.rel_path)
  raise Error.not_found if !item 

  req.respond(@machine.file_read(item[:fn]), 'Content-Type' => item[:mime_type])
}
