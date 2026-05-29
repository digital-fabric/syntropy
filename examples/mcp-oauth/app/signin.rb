AuthStore = import '../_lib/auth_store'

export ->(req) {
  case req.method
  when 'get'
    render_signin_form(req)
  when 'post'
    validate_signin(req)
  else
    raise Syntropy::Error.method_not_allowed
  end
}

def render_signin_form(req)
  req.respond_html(@signin_form.render)
end

def validate_signin(req)
  creds = req.get_form_data

  if !valid_creds?(creds)
    req.respond_html(
      @signin_form.render,
      ':status' => Syntropy::HTTP::UNAUTHORIZED
    )
    return
  end

  sid = AuthStore.store({
    username: creds['username'],
    timestamp: Time.now.to_i
  })

  oauth_signin_id = req.cookies['oauth_signin_id']
  if oauth_signin_id
    auth_info = AuthStore.fetch(oauth_signin_id)
    AuthStore.update(oauth_signin_id, auth_info.merge('sid' => sid))
    req.validate(auth_info, Hash)
    req.respond(
      nil,
      ':status'     => Syntropy::HTTP::SEE_OTHER,
      'Location'    => '/oauth/consent',
    )
    return
  end

  req.respond(
      nil,
      ':status'     => Syntropy::HTTP::SEE_OTHER,
      'Location'    => '/',
      'Set-Cookie'  => "sid=#{sid}"
    )
end

def valid_creds?(creds)
  (creds['username'] == 'foobar') && (creds['password'] == 'foobar')
end

@signin_form = template {
  html {
    head {
      title 'My awesome site'
    }
    body {
      h1 'Sign in:'

      form(method: 'post') {
        div {
          label 'username:', for: 'username'
          input type: 'text', name: 'username', required: true
        }

        div {
          label 'password:', for: 'password'
          input type: 'password', name: 'password', required: true
        }

        div {
          input type: 'submit', value: 'Submit'
        }
      }
    }
    auto_refresh!
  }
}
