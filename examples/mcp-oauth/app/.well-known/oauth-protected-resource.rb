# https://datatracker.ietf.org/doc/html/rfc9728#name-protected-resource-metadata
export ->(req) {
  req.respond_json(
    {
      resource:                 "http://localhost:1234/",
      authorization_servers:    ["http://localhost:1234/"],
      scopes_supported:         ["mcp:read", "mcp:write"]
    }
  )
}
