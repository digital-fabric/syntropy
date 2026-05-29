AuthStore = import '../_lib/auth_store'

# https://datatracker.ietf.org/doc/html/rfc6749#section-5
export ->(req) do
  req.validate_http_method('post')
  params = req.get_form_data
  req.validate(
    params['redirect_uri'], String,
    message: 'invalid_request'
  )

  req.validate(
    params['grant_type'], 'authorization_code',
    message: 'unsupported_grant_type'
  )

  code = params['code']
  auth_info = AuthStore.fetch(code)
  req.validate(
    auth_info, Hash,
    message: 'invalid_request'
  )

  req.validate(
    params['redirect_uri'], auth_info['redirect_uri'],
    message: 'invalid_request'
  )

  client_id = params['client_id']
  client_info = AuthStore.fetch(client_id)
  req.validate(
    client_info, Hash,
    message: 'invalid_client'
  )

  code_verifier = params['code_verifier']
  hashed = Base64.urlsafe_encode64(Digest::SHA256.digest(code_verifier), padding: false)
  req.validate(
    hashed, auth_info['code_challenge'],
    message: 'invalid_grant'
  )

  session_info = AuthStore.fetch(auth_info['sid'])
  req.validate(
    session_info, Hash,
    message: 'invalid_grant'
  )

  token_info = session_info.merge(
    # some app-specific metadata
    type: 'oauth',
    ttl: 86400 * 30
  )
  token = AuthStore.store(token_info)

  req.respond_json({
    access_token: token,
    token_type: 'Bearer',
    expires_in: token_info[:ttl]
  })
rescue ValidationError => e
  req.respond_json(
    {
      error: e.message
    },
    ':status' => Syntropy::HTTP::BAD_REQUEST
  )
rescue => e
  status = Syntropy::Error.http_status(e)
  raise if status == HTTP::INTERNAL_SERVER_ERROR

  req.respond_json(
    {
      error: 'invalid_request',
      error_description: e.message
    },
    ':status' => Syntropy::HTTP::BAD_REQUEST
  )
end
