## App rewrite

- [v] Integration with module loader (which should be refactored into separate
  file - actually needs a rewrite.)
- [v] Add `Request#route` which is set to the route entry
- [v] Add `Request#validate_route_param`, works like `#validate_param`
- [v] Add possibility to validate with a block:

      ```ruby
      org = validate_route_param(:org) { store.get_org(it) }
      repo = validate_route_param(:org) { org.get_repo(it) }
      ```

      Maybe a better possibility is to implement a general `#validate` method:

      ```ruby
      org = validate(route_param[:org]) { store.get_org(it) }
      repo = validate(route_param[:org]) { org.get_repo(it) }
      issue = validate(route_param[:issue_id]) { repo.issues[it] }
      ```

      This could also be used with POST params:

      ```ruby
      body = req.read
      form_data = req.parse_form_data(body, req.headers)
      category = req.validate(form_data[:category]) { store.categories[it.to_i] }
      ```

      This could also be expressed as:

      ```ruby
      body = req.get_form_data
      category = req.validate(form_data[:category]) { store.categories[it.to_i] }
      ```

- [ ] Add `Request#get_form_data` extension, with __tests__:

      ```ruby
      def get_form_data
        body = read
        form_data = parse_form_data(body, headers)
      end
      ```

- [ ] Tests for Syntropy::Error


## Support for applets

- can be implemented as separate gems
- can route requests to a different directory (i.e. inside the gem directory)
- simple way to instantiate and setup the applet
- as a first example, implement an auth/signin applet:
  - session hook
  - session persistence
  - login page
  - support for custom behaviour and custom workflows (2FA, signin using OTP etc.)

Example usage:

```ruby
# /admin+.rb
require 'syntropy/admin'

export Syntropy::Admin.new(@ref, @env)
```

Implementation:

```ruby
# syntropy-admin/lib/syntropy/admin.rb
APP_ROOT = File.expand_path(File.join(__dir__, '../../app'))

class Syntropy::Admin < Syntropy::App
  def new(mount_path, env)
    super(env[:machine], APP_ROOT, mount_path, env)
  end
end
```

## Response: cookies and headers

We need a way to inject cookies into the response. This probably should be done
in the TP2 code:

```ruby
@@default_set_cookie_attr = 'HttpOnly'
def self.default_set_cookie_attr=(v)
  @@default_set_cookie_attr = v
end

def set_cookie(key, value, attr = @@default_set_cookie_attr)
  @buffered_headers ||= +''
  @buffered_headers << format(
    "Set-Cookie: %<key>s=%<value>s; %<attr>s\n",
    key:, value:, attr:
  )
end

def set_headers(headers)
  @buffered_headers ||= +''
  @buffered_headers << format_headers(headers)
end

...

req.set_cookie('at', 'foobar', 'SameSite=none; Secure; HttpOnly')
```

## Middleware

Some standard middleware:

- request rewriter
- logger
- auth
- selector + terminator

```Ruby
# For the chainable DSL shown below, we need to create a custom class:
class Syntropy::Middleware::Selector
  def initialize(select_proc, terminator_proc = nil)
    @select_proc = select_proc
    @terminator_proc = terminator_proc
  end

  def to_proc
    ->(req, proc) {
      @select_proc.(req) ? @terminator_proc.(req) : proc(req)
    }
  end

  def terminate(&proc)
    @terminator_proc = proc
  end
end
```

```Ruby
# a _site.rb file can be used to wrap a whole app
# site/_site.rb

# this means we route according to the host header, with each
export Syntropy.route_by_host

# we can also rewrite requests:
rewriter = Syntropy
  .select { it.host =~ /^tolkora\.(org|com)$/ }
  .terminate { it.redirect_permanent('https://tolkora.net') }

# This is actuall a pretty interesting DSL design:
# a chain of operations that compose functions. So, we can select a
export rewriter.wrap(default_app)

# composing
export rewriter.wrap(Syntropy.some_custom_app.wrap(app))

# or maybe
export rewriter << some_other_middleware << app
```

## CLI tool for setting up a site repo:

```bash
# clone a newly created repo
~/repo$ git clone https://github.com/foo/bar
...
~/repo$ syntropy setup bar

(syntropy banner)

Setting up Syntropy project in /home/sharon/repo/bar:

bar/
  bin/
    start
    stop
    restart
    console
    server
  docker-compose.yml
  Dockerfile
  Gemfile
  proxy/
  README.md
  site/
    _layout/
      default.rb
    _lib/
    about.md
    articles/
      long-form.md
    assets/
      js/
      css/
        style.css
      img/
        syntropy.png
    index.rb
```

Some of the files might need templating, but we can maybe do without, or at
least make it as generic as possible.

`syntropy setup` steps:

1. Verify existence of target directory
2. Copy files from Syntropy template to target directory
3. Do chmod +x for bin/*
4. Do bundle install in the target directory
5. Show some information with regard to how to get started working with the
   repo

`syntropy provision` steps:

1. Verify Ubuntu 22.x or higher
2. Install git, docker, docker-compose

`syntropy deploy` steps:

1. Verify no uncommitted changes.
2. SSH to remote machine.
  2.1. If not exists, clone repo
  2.2. Otherwise, verify remote machine repo is on same branch as local repo
  2.3. Do a git pull (what about credentials?)
  2.4. If gem bundle has changed, do a docker compose build
  2.5. If docker compose services are running, restart
  2.6. Otherwise, start services
  2.7. Verify service is running correctly
