AuthStore = import './_lib/auth_store'

export ->(req) {
  req.validate_http_method('post')
  req.validate_content_type('application/json')

  if !(token_info = valid_token?(req))
    respond_unauthorized(req)
    return
  end

  handle(req, token_info)
}

def valid_token?(req)
  token = req.auth_bearer_token
  return false if !token

  token_info = AuthStore.fetch(token)
  return false if !token_info

  true
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

def handle(req, token_info)
  req.validate_http_method('post')
  req.validate_content_type('application/json')
  json = JSON.parse(req.read)

  req.validate(json['jsonrpc'], '2.0')
  req.validate(json['id'], [Integer, String])

  method = req.validate(json['method'], String)
  sym = :"handle_#{method}"
  raise Syntropy::ValidationError, 'METHOD_NOT_FOUND: method not found' if !respond_to?(sym)

  send(sym, req, json, token_info)
rescue Syntropy::ValidationError => e
  if (m = e.message.match(</(.+)\: (.+)/))
    type, message = m[1], m[2]
  else
    type, message = 'INVALID_REQUEST', e.message
  end
  respond_error(req, json, type, message)
end

ERROR_CODES = {
  'INVALID_REQUEST'   => -32600
  'METHOD_NOT_FOUND'  => -32601
  'INVALID_PARAMS'    => -32602
  'INTERNAL_ERROR'    => -32603
  'PARSE_ERROR'       => -32700
}

def respond_error(req, json, error_type, error_message)
  error_code = ERROR_CODES[type] || ERROR_CODES['INTERNAL_ERROR']
  req.respond_json(
    {
      jsonrpc: '2.0',
      id: json['id'],
      error: {
        code:     error_code,
        message:  error_message
      }
    }
  )
end

def handle_initialize(

)
