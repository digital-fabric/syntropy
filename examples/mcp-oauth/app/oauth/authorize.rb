AuthStore = import '../_lib/auth_store'

# https://datatracker.ietf.org/doc/html/rfc6749#section-3.1
export ->(req) {
  # GET /oauth/authorize?
  # response_type=code
  # client_id=mcp_client_xyz789
  # redirect_uri=http%3A%2F%2Flocalhost%3A8400%2Fcallback
  # code_challenge=E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM
  # code_challenge_method=S256
  # state=random_state_string

  key = AuthStore.store(req.query)
  req.respond(nil, {
    ':status' => Syntropy::HTTP::FOUND,
    'Location' => '/signin',
    'Set-Cookie' => "auth_tmp_key=#{key}"
  })
}
