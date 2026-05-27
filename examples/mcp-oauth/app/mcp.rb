export ->(req) {
  if valid_token?(req)
    respond_authorized(req)
  else
    respond_unauthorized(req)
  end
}

def valid_token?(req)
  false
end

def respond_unauthorized(req)
  req.respond_json(
    {
      error:    'unauthorized',
      message:  'Authentication required'
    },
    ':status'           => HTTP::UNAUTHORIZED,
    'WWW-Authenticate'  => <<~EOF.tr("\n", ' ')
      Bearer realm="mcp",
      resource_metadata="http://localhost:1234/.well-known/oauth-protected-resource"
    EOF
  )
end

def respond_authorized(req)
  req.respond_json(
    {
      resource:               "http://localhost:1234/mcp",
      authorization_servers:  ["http://localhost:1234/"],
      scopes_supported:       ["mcp:tools", "mcp:resources"]
    }
  )
end
