repos   = import '/_repos'

export ->(req) {
  req.validate_http_method('get')
  repo = repos[req.route_params[:repo]]
  raise Error.not_found if !repo

  advertise(req, repo)
}

def advertise(req, repo)
  refs = repo.advertise_refs
  body = pkt("# service=git-upload-pack\n") + '0000' + refs
  req.respond(body, 'Content-Type' => 'application/x-git-upload-pack-advertisement')
end

def pkt(line)
  format('%04x%s', line.bytesize + 4, line)
end
