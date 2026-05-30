# Syntropy OAuth 2.1 Example App

This app implements a site that includes an MCP server with OAuth 2.1 authorization.

## Authorization workflow:

### Phase 1: Discovery

- MCP client accesses the mcp endpoint:

  `GET /mcp`

  Response headers:

  ```
  HTTP/1.1 401 Unauthorized
  WWW-Authenticate: Bearer realm="mcp", resource_metadata="http://localhost:1234/.well-known/oauth-protected-resource"
  ```

- MCP client makes a request to the protected resource endpoint in order to the
  protected resource metadata:

  `GET /.well-known/oauth-protected-resource`

  Response JSON:

  ```
  {
    resource:               "http://localhost:1234/",
    authorization_servers:  ["http://localhost:1234/"],
    scopes_supported:       ["mcp:read", "mcp:write"]
  }
  ```

- MCP client makes a request to the authorization server:

  `GET /.well-known/oauth-authorization-server`

  Response JSON:

  ```
  {
    issuer:                                 "http://localhost:1234/",
    registration_endpoint:                  "http://localhost:1234/oauth/register",
    authorization_endpoint:                 "http://localhost:1234/oauth/authorize",
    token_endpoint:                         "http://localhost:1234/oauth/token",
    scopes_supported:                       ["mcp:read", "mcp:write"],
    response_types_supported:               ["code"]
  }
  ```

### Phase 2: Dynamic Client Registration (DCR)

- MCP client makes a request to the register endpoint

  ```
  POST /oauth/register
  Content-Type: application/json

  {
    "client_name": "Cursor AI Agent",
    "redirect_uris": ["http://localhost:8400/callback"],
    "grant_types": ["authorization_code", "refresh_token"]
  }
  ```

  Response:

  ```
  HTTP/1.1 201 Created
  Content-Type: application/json

  {
    "client_id": "mcp_client_xyz789",
    "client_name": "Cursor AI Agent",
    "redirect_uris": ["http://localhost:8400/callback"],
    "grant_types": ["authorization_code", "refresh_token"]
  }
  ```

### Phase 3: Authorization Request with PKCE

- MCP client opens a browser with a URL pointing to the authorization endpoint:

  `GET /oauth/authorize?response_type=code&client_id=mcp_client_xyz789&redirect_uri=http%3A%2F%2Flocalhost%3A8400%2Fcallback&code_challenge=E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM&code_challenge_method=S256&state=random_state_string HTTP/1.1`

  the server leads the user through signin and consent workflow. Finally it
  generates a temporary auth code and redirects to the client's callback URL:

  Response:

  ```
  HTTP/1.1 302 Found
  Location: http://localhost:8400/callback?code=splat-auth-code-123&state=random_state_string
  ```

### Phase 4: Token Exchange

- MCP client grabs the code and exchanges it with the token endpoint:

  ```
  POST /oauth/token HTTP/1.1
  Host: auth.example.com
  Content-Type: application/x-www-form-urlencoded

  grant_type=authorization_code&code=splat-auth-code-123&redirect_uri=http%3A%2F%2Flocalhost%3A8400%2Fcallback&client_id=mcp_client_xyz789&code_verifier=dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk
  ```

  The authorization server hashes the code_verifier and verifies it matches the
  challenge submitted in Phase 3. If it does, it returns an access token:

  ```
  HTTP/1.1 200 OK
  Content-Type: application/json

  {
    "access_token": "mcp_access_token_abc123",
    "token_type": "Bearer",
    "expires_in": 3600,
    "refresh_token": "mcp_refresh_token_def456"
  }
  ```

### And we're done

The client can now seamlessly access the MCP resources by attaching the header:

`Authorization: Bearer mcp_access_token_abc123`
