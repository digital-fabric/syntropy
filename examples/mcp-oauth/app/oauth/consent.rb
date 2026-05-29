AuthStore = import '../_lib/auth_store'

export ->(req) {
  case req.method
  when 'get'
    render_consent_form(req)
  when 'post'
    validate_consent(req)
  else
    raise Syntropy::Error.method_not_allowed
  end
}

def render_consent_form(req)
  oauth_signin_id = req.cookies['oauth_signin_id']
  auth_info = AuthStore.fetch(oauth_signin_id)
  req.validate(auth_info, Hash)

  client_id = auth_info['client_id']
  req.validate(client_id, String)
  client_info = AuthStore.fetch(client_id)

  sid = auth_info['sid']
  req.validate(sid, String)
  session_info = AuthStore.fetch(sid)

  req.respond_html(@consent_form.render(client_info, session_info))
end

def validate_consent(req)
  data = req.get_form_data
  decision = data['decision']
  req.validate(decision, ['deny', 'allow'])

  oauth_signin_id = req.cookies['oauth_signin_id']
  auth_info = AuthStore.fetch(oauth_signin_id)
  req.validate(auth_info, Hash)

  callback_query = case decision
  when 'deny'
    {
      error: 'access_denied',
      state: auth_info['state']
    }
  when 'allow'
    auth_code = AuthStore.store(auth_info)
    {
      code: auth_code,
      state: auth_info['state']
    }
  end

  uri = format(
    '%s?%s', auth_info['redirect_uri'],
    URI.encode_www_form(callback_query)
  )
  req.respond(
    nil,
    ':status' => Syntropy::HTTP::FOUND,
    'Location' => uri
  )
end

@consent_form = template { |client_info, session_info|
  html {
    head {
      title 'My awesome site'
    }
    body {
      h2 client_info['client_name']
      p {
        span 'wants to access my awesome site on behalf of '
        em session_info[:username]
        span '.'
      }

      form(action: '') {
        div {
          button 'Deny',  type: 'submit', name: 'decision', value: 'deny'
          button 'Allow', type: 'submit', name: 'decision', value: 'allow'
        }
      }
    }
    auto_refresh!
  }
}
