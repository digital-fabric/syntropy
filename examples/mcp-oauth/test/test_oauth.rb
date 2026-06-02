# frozen_string_literal: true

require 'base64'
require 'digest'

class OAuthBaseTest < Syntropy::Test
  def setup
    super
    @store = load_module('_lib/auth_store')
  end
end

class AuthStoreTest < OAuthBaseTest
  def test_auth_store
    assert_nil @store.fetch('foo')

    o = { a: 1, b: 2 }
    key = @store.store(o)
    assert_kind_of String, key
    assert_equal o, @store.fetch(key)

    assert_equal o, @store.fetch_and_remove(key)
    assert_nil @store.fetch(key)
  end
end

class OAuthPhase1DiscoveryTest < OAuthBaseTest
  def test_mcp_no_bearer_token
    req = post_json(
      '/mcp',
      {
        method: 'initialize',
        jsonrpc: '2.0',
        params: {}
      }
    )

    assert_equal HTTP::UNAUTHORIZED, req.response_status

    www_auth = req.response_headers['WWW-Authenticate']
    assert_match /realm="mcp"/, www_auth
    assert_match /#{'resource_metadata="http://localhost:1234/.well-known/oauth-protected-resource"'}/, www_auth
  end

  def test_mcp_invalid_bearer_token
    req = post_json(
      '/mcp',
      {
        method: 'initialize',
        jsonrpc: '2.0',
        params: {}
      },
      'authorization' => 'Bearer foobar'
    )
    assert_equal HTTP::UNAUTHORIZED, req.response_status

    www_auth = req.response_headers['WWW-Authenticate']
    assert_match /realm="mcp"/, www_auth
    assert_match /#{'resource_metadata="http://localhost:1234/.well-known/oauth-protected-resource"'}/, www_auth
  end

  def test_oauth_protected_resource_metadatas
    req = get('/.well-known/oauth-protected-resource')
    assert_equal HTTP::OK, req.response_status
    json = req.response_json
    assert_equal ["http://localhost:1234/"],  json['authorization_servers']
    assert_equal ["mcp:read", "mcp:write"],   json['scopes_supported']
  end

  def test_oauth_authorization_server_metadata
    req = get('/.well-known/oauth-authorization-server')
    assert_equal HTTP::OK, req.response_status
    json = req.response_json
    assert_equal "http://localhost:1234/",                json['issuer']
    assert_equal "http://localhost:1234/oauth/register",  json['registration_endpoint']
    assert_equal "http://localhost:1234/oauth/authorize", json['authorization_endpoint']
    assert_equal "http://localhost:1234/oauth/token",     json['token_endpoint']
    assert_equal ["mcp:read", "mcp:write"],               json['scopes_supported']
    assert_equal ["code"],                                json['response_types_supported']
  end
end

class OAuthPhase2ClientRegistrationTest < OAuthBaseTest
  def test_oauth_register_endpoint
    client_info = {
      "client_name"   => "My AI Agent",
      "redirect_uris" => ["http://localhost:8400/callback"],
      "grant_types"   => ["authorization_code", "refresh_token"]
    }

    req = post_json(
      '/oauth/register',
      client_info,
      'authorization' => 'Bearer foobar'
    )

    assert_equal HTTP::CREATED, req.response_status
    json = req.response_json

    client_id = json['client_id']
    assert_kind_of String, client_id
    assert_equal client_info, @store.fetch(client_id)

    assert_equal client_info['client_name'],    json['client_name']
    assert_equal client_info['redirect_uris'],  json['redirect_uris']
    assert_equal client_info['grant_types'],    json['grant_types']
  end
end

class OAuthPhase3AuthorizationTest < OAuthBaseTest
  def test_oauth_authorization_endpoint
    # register client
    client_info = {
      "client_name"   => "My AI Agent",
      "redirect_uris" => ["http://localhost:8400/callback"],
      "grant_types"   => ["authorization_code", "refresh_token"]
    }
    req = post_json(
      '/oauth/register',
      client_info,
      'authorization' => 'Bearer foobar'
    )
    assert_equal HTTP::CREATED, req.response_status
    json = req.response_json
    client_id = json['client_id']

    params = {
      'response_type'         => 'code',
      'client_id'             => client_id,
      'redirect_uri'          => 'http://localhost:4321/callback',
      'code_challenge'        => SecureRandom.hex(16),
      'code_challenge_method' => 'S256',
      'state'                 => 'my_state'
    }
    req = get("/oauth/authorize?#{URI.encode_www_form(params)}")
    assert_equal HTTP::FOUND, req.response_status
    assert_equal '/signin', req.response_headers['Location']

    set_cookie = req.response_headers['Set-Cookie']
    refute_nil set_cookie
    m = set_cookie.match(/oauth_signin_id=([^\s]+)$/)
    signin_id = m[1]

    assert_equal params, @store.fetch(signin_id)
  end

  def test_oauth_signin_with_oauth_signin_id
    client_info = {
      "client_name"   => "My AI Agent",
      "redirect_uris" => ["http://localhost:8400/callback"],
      "grant_types"   => ["authorization_code", "refresh_token"]
    }
    client_id = @store.store(client_info)

    auth_params = {
      response_type:          'code',
      client_id:              client_id,
      redirect_uri:           'http://localhost:4321/callback',
      code_challenge:         SecureRandom.hex(16),
      code_challenge_method:  'S256',
      state:                  'my_state'
    }
    oauth_signin_id = @store.store(auth_params)

    req = post_form(
      '/signin',
      { username: 'foobar', password: 'foobar' },
      'cookie' => "oauth_signin_id=#{oauth_signin_id}",
    )

    auth_info = @store.fetch(oauth_signin_id)
    sid = auth_info['sid']
    refute_nil sid
    session_info = @store.fetch(sid)
    assert_kind_of Hash, session_info
    assert_equal 'foobar', session_info[:username]

    assert_equal HTTP::SEE_OTHER, req.response_status
    assert_equal '/oauth/consent', req.response_headers['Location']
  end

  def test_signin_endpoint_get
    req = get('/signin')
    assert_equal HTTP::OK, req.response_status
    assert_equal 'text/html', req.response_content_type
  end

  def test_signin_endpoint_post_bad_creds
    req = post_form(
      '/signin',
      { username: 'foobar', password: 'bad' }
    )
    assert_equal HTTP::UNAUTHORIZED, req.response_status
    assert_equal 'text/html', req.response_content_type
    assert_nil req.response_headers['Set-Cookie']
  end

  def test_signin_endpoint_post_good_creds
    req = post_form(
      '/signin',
      { username: 'foobar', password: 'foobar' }
    )
    assert_equal HTTP::SEE_OTHER, req.response_status
    assert_equal '/', req.response_headers['Location']
    sid = req.response_cookie('sid')
    refute_nil sid

    info = @store.fetch(sid)
    assert_kind_of Hash, info
    assert_equal 'foobar', info[:username]
  end

  def test_oauth_consent_endpoint_get_no_oauth_signin_id
    req = get('/oauth/consent')
    assert_equal HTTP::BAD_REQUEST, req.response_status
  end

  def test_oauth_consent_endpoint_get_invalid_oauth_signin_id
    req = get(
      '/oauth/consent',
      'cookie' => 'outh_signin_id=foo'
    )
    assert_equal HTTP::BAD_REQUEST, req.response_status
  end

  def test_oauth_consent_endpoint_get_valid_oauth_signin_id
    client_info = {
      "client_name"   => "My AI Agent",
      "redirect_uris" => ["http://localhost:8400/callback"],
      "grant_types"   => ["authorization_code", "refresh_token"]
    }
    client_id = @store.store(client_info)

    session_info = {
      username: 'foobar'
    }
    sid = @store.store(session_info)

    auth_params = {
      'response_type'         => 'code',
      'client_id'             => client_id,
      'redirect_uri'          => 'http://localhost:4321/callback',
      'code_challenge'        => SecureRandom.hex(16),
      'code_challenge_method' => 'S256',
      'state'                 => 'my_state',
      'sid'                   => sid
    }
    oauth_signin_id = @store.store(auth_params)

    req = get(
      '/oauth/consent',
      'cookie' => "oauth_signin_id=#{oauth_signin_id}"
    )
    assert_equal HTTP::OK, req.response_status
  end

  def test_oauth_consent_endpoint_post_deny
    client_info = {
      "client_name"   => "My AI Agent",
      "redirect_uris" => ["http://localhost:8400/callback"],
      "grant_types"   => ["authorization_code", "refresh_token"]
    }
    client_id = @store.store(client_info)

    session_info = {
      username: 'foobar'
    }
    sid = @store.store(session_info)

    auth_params = {
      'response_type'         => 'code',
      'client_id'             => client_id,
      'redirect_uri'          => 'http://localhost:4321/callback',
      'code_challenge'        => SecureRandom.hex(16),
      'code_challenge_method' => 'S256',
      'state'                 => 'my_state',
      'sid'                   => sid
    }
    oauth_signin_id = @store.store(auth_params)

    req = post_form(
      '/oauth/consent',
      { decision: 'deny' },
      'cookie'  => "oauth_signin_id=#{oauth_signin_id}"
    )
    assert_equal HTTP::FOUND, req.response_status

    deny_uri = "http://localhost:4321/callback?error=access_denied&state=my_state"
    assert_equal deny_uri, req.response_headers['Location']
  end

  def test_oauth_consent_endpoint_post_allow
    client_info = {
      "client_name"   => "My AI Agent",
      "redirect_uris" => ["http://localhost:8400/callback"],
      "grant_types"   => ["authorization_code", "refresh_token"]
    }
    client_id = @store.store(client_info)

    session_info = {
      username: 'foobar'
    }
    sid = @store.store(session_info)

    auth_params = {
      'response_type'         => 'code',
      'client_id'             => client_id,
      'redirect_uri'          => 'http://localhost:4321/callback',
      'code_challenge'        => SecureRandom.hex(16),
      'code_challenge_method' => 'S256',
      'state'                 => 'my_state',
      'sid'                   => sid
    }
    oauth_signin_id = @store.store(auth_params)

    req = post_form(
      '/oauth/consent',
      { decision: 'allow' },
      'cookie'  => "oauth_signin_id=#{oauth_signin_id}"
    )
    assert_equal HTTP::FOUND, req.response_status

    u = URI.parse(req.response_headers['Location'])
    q = URI.decode_www_form(u.query).to_h
    u.query = nil
    assert_equal 'http://localhost:4321/callback', u.to_s
    assert_equal 'my_state', q['state']
    assert_kind_of String, q['code']

    code_info = @store.fetch(q['code'])
    assert_equal auth_params, code_info
  end
end

class OAuthPhase4AuthorizationTest < OAuthBaseTest
  def setup
    super
    @client_info = {
      "client_name"   => "My AI Agent",
      "redirect_uris" => ["http://localhost:8400/callback"],
      "grant_types"   => ["authorization_code", "refresh_token"]
    }
    @client_id = @store.store(@client_info)

    @session_info = {
      username: 'foobar'
    }
    @sid = @store.store(@session_info)

    @code_verifier = SecureRandom.hex(16)
    @code_challenge = Base64.urlsafe_encode64(Digest::SHA256.digest(@code_verifier), padding: false)

    @auth_params = {
      'response_type'         => 'code',
      'client_id'             => @client_id,
      'redirect_uri'          => 'http://localhost:4321/callback',
      'code_challenge'        => @code_challenge,
      'code_challenge_method' => 'S256',
      'state'                 => 'my_state',
      'sid'                   => @sid
    }
    @auth_code = @store.store(@auth_params)
  end

  def test_oauth_token_exchange
    req = post_form(
      '/oauth/token',
      {
        grant_type:     'authorization_code',
        code:           @auth_code,
        redirect_uri:   'http://localhost:4321/callback',
        client_id:      @client_id,
        code_verifier:  @code_verifier
      }
    )

    assert_equal HTTP::OK, req.response_status
    assert_equal 'application/json', req.response_content_type
    json = req.response_json

    at = json['access_token']
    assert_kind_of String, at
    token_info = @store.fetch(at)
    refute_nil token_info
    assert_equal @session_info[:username], token_info[:username]
    assert_equal 'oauth', token_info[:type]

    assert_equal 'Bearer', json['token_type']
    assert_kind_of Integer, json['expires_in']
  end

  def test_oauth_token_exchange_missing_params
    req = post_form(
      '/oauth/token', {}
    )

    assert_equal HTTP::BAD_REQUEST, req.response_status
    assert_equal 'application/json', req.response_content_type
    json = req.response_json

    error = json['error']
    assert_equal 'invalid_request', error
  end

  def test_oauth_token_exchange_invalid_grant_type
    req = post_form(
      '/oauth/token',
      {
        grant_type: 'foo',
        code: @auth_code,
        redirect_uri: 'http://localhost:4321/callback',
        client_id: @client_id,
        code_verifier: @code_verifier
      }
    )

    assert_equal HTTP::BAD_REQUEST, req.response_status
    assert_equal 'application/json', req.response_content_type
    json = req.response_json

    error = json['error']
    assert_equal 'unsupported_grant_type', error
  end

  def test_oauth_token_exchange_invalid_code
    req = post_form(
      '/oauth/token',
      {
        grant_type:     'authorization_code',
        code:           @auth_code + '!',
        redirect_uri:   'http://localhost:4321/callback',
        client_id:      @client_id,
        code_verifier:  @code_verifier
      }
    )

    assert_equal HTTP::BAD_REQUEST, req.response_status
    assert_equal 'application/json', req.response_content_type
    json = req.response_json

    error = json['error']
    assert_equal 'invalid_request', error
  end

  def test_oauth_token_exchange_invalid_redirect_uri
    req = post_form(
      '/oauth/token',
      {
        grant_type:     'authorization_code',
        code:           @auth_code,
        redirect_uri:   'http://localhost:4321/foo',
        client_id:      @client_id,
        code_verifier:  @code_verifier
      }
    )

    assert_equal HTTP::BAD_REQUEST, req.response_status
    assert_equal 'application/json', req.response_content_type
    json = req.response_json

    error = json['error']
    assert_equal 'invalid_request', error
  end

  def test_oauth_token_exchange_invalid_client_id
    req = post_form(
      '/oauth/token',
      {
        grant_type:     'authorization_code',
        code:           @auth_code + '!',
        redirect_uri:   'http://localhost:4321/callback',
        client_id:      @client_id + 'foo',
        code_verifier:  @code_verifier
      }
    )

    assert_equal HTTP::BAD_REQUEST, req.response_status
    assert_equal 'application/json', req.response_content_type
    json = req.response_json

    error = json['error']
    assert_equal 'invalid_request', error
  end

  def test_oauth_token_exchange_invalid_code_verifier
    req = post_form(
      '/oauth/token',
      {
        grant_type:     'authorization_code',
        code:           @auth_code + '!',
        redirect_uri:   'http://localhost:4321/callback',
        client_id:      @client_id,
        code_verifier:  @code_verifier + 'abc'
      }
    )

    assert_equal HTTP::BAD_REQUEST, req.response_status
    assert_equal 'application/json', req.response_content_type
    json = req.response_json

    error = json['error']
    assert_equal 'invalid_request', error
  end
end
