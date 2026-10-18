require 'zlib'
require 'stringio'

repos   = import '/_repos'

export ->(req) {
  req.validate_http_method('post')
  repo = repos[req.route_params[:repo]]
  raise Error.not_found if !repo

  input = req.read
  input = Zlib::GzipReader.new(StringIO.new(input)).read if req.headers['content-encoding'] == 'gzip'

  req.send_headers(':status' => 200, 'Content-Type' => 'application/x-upload-pack-result')
  repo.rpc(@machine, 'upload-pack', input) {
    p len: it.bytesize
    req.adapter.io.write(it)
  }

  # req.respond(out, 'Content-Type' => "application/x-upload-pack-result")
}
