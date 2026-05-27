# https://datatracker.ietf.org/doc/html/rfc8414#section-2
export ->(req) {
  req.respond_json(
    {
      issuer:                                 "http://localhost:1234/",
      authorization_endpoint:                 "http://localhost:1234/oauth/authorize",
      token_endpoint:                         "http://localhost:1234/oauth/token",
      scopes_supported:                       ["mcp:read", "mcp:write"],
      response_types_supported:               ["code"]
      # registration_endpoint:                  "http://localhost:1234/register",
      # jwks_uri:                               "http://localhost:1234/.well-known/jwks.json",
      # grant_types_supported:                  ["authorization_code", "refresh_token"],
      # code_challenge_methods_supported:       ["S256"],
      # claims_supported:                       ["aud", "iss", "exp", "scope", "sub"],
      # client_id_metadata_document_supported:  true
    }
  )
}
