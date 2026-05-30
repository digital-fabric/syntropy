AuthStore = import '../_lib/auth_store'

# https://datatracker.ietf.org/doc/html/rfc6749#section-3.1
export ->(req) {
  req.validate_http_method('get')
  params = req.query
  req.validate(params['response_type'], 'code')

  client_info = AuthStore.fetch(params['client_id'])
  req.validate(client_info, Hash)

  key = AuthStore.store(req.query)
  req.respond(nil, {
    ':status' => Syntropy::HTTP::FOUND,
    'Location' => '/signin',
    'Set-Cookie' => "oauth_signin_id=#{key}"
  })
}
