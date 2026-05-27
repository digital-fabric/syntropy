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
  if valid_creds(creds)
    auth_key = req.cookies['auth_tmp_key']
    req.respond(
      ':status' => Syntropy::HTTP::FOUND,
      'Location' => ''
    )
  else
    req.respond_html(signin_form.render)
  end
end

@signin_form = template {
  html {
    head {
      title 'My awesome site'
    }
    body {
      h1 'Sign in:'

      form(action: '') {
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
