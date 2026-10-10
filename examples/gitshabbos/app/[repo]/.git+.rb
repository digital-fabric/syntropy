require 'open3'

repos   = import '../../_repos'

export ->(req) {
  req.validate_http_method('get')

  repo = repos[req.route_params[:repo]]
  raise Error.not_found if !repo

  puts '*' * 40
  p query: req.query
  p rel_path: req.rel_path
  
  case req.rel_path
  when 'info/refs'
    if req.query['service'] != 'git-upload-pack'
      raise Error.new('Bad request', HTTP::BAD_REQUEST)
    end
    body = generate_info_refs_body(repo.path)
    req.respond(body, 'Content-Type' => 'Content-Type: application/x-git-upload-pack-advertisement')
  else
    raise Error.bad_request
  end
}

def generate_info_refs_body(repo_path)
  # Execute the git CLI command in stateless RPC advertisement mode
  stdout_str, status = Open3.capture2('git', 'upload-pack', '--stateless-rpc', '--advertise-refs', repo_path)
  
  return nil unless status.success?

  # Smart HTTP header prefix: length (001e) + payload + flush packet (0000)
  header = "001e# service=git-upload-pack\n0000"
  
  header + stdout_str
end
