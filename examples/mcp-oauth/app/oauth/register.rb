AuthStore = import '../_lib/auth_store'

# https://datatracker.ietf.org/doc/html/rfc7591
export ->(req) {
  req.validate_http_method('post')
  req.validate_content_type('application/json')

  client_info = JSON.parse(req.read)
  client_id = AuthStore.store(client_info)

  req.respond_json(
    { client_id: }.merge(client_info),
    ':status' => HTTP::CREATED
  )
}
