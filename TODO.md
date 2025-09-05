## Immediate

- [ ] Collection - treat directories and files as collections of data.

  Kind of similar to the routing tree, but instead of routes it just takes a
  bunch of files and turns it into a dataset. Each directory is a "table" and is
  composed of zero or more files that form rows in the table. Supported file
  formats:

  - foo.md - markdown with optional front matter
  - foo.json - JSON record
  - foo.yml - YAML record

  API:

  ```ruby
  Articles = @app.collection('_articles/*.md')
  article = Articles.last_by(&:date)

  article.title #=>
  article.date #=>
  article.layout #=>
  article.render_proc #=> (load layout, apply article)
  article.render #=> (render to HTML)

  # there should also be methods for creating, updating and deleting of articles/items.
  ...
  ```

- [ ] Improve serving of static files:
  - [ ] support for compression
  - [ ] support for caching headers
  - [ ] add `Request#render_static_file(route, fn)

- [ ] Serving of built-in assets (mostly JS)
  - [ ] JS lib for RPC API
  
## Missing for a first public release

- [ ] Logo
- [ ] Website
- [ ] Frontend part of RPC API
- [v] Auto-refresh page when file changes
- [ ] Examples
  - [ ] Reactive app - counter or some other simple app showing interaction with server
  - [ ] ?

## Counter example

Here's a react component (from https://fresh.deno.dev/):

```jsx
// islands/Counter.tsx
import { useSignal } from "@preact/signals";

export default function Counter(props) {
  const count = useSignal(props.start);

  return (
    <div>
      <h3>Interactive island</h3>
      <p>The server supplied the initial value of {props.start}.</p>
      <div>
        <button onClick={() => count.value -= 1}>-</button>
        <div>{count}</div>
        <button onClick={() => count.value += 1}>+</button>
      </div>
    </div>
  );
}
```

How do we do this with Syntropy? Can we make a component that does the
templating and the reactivity in a single file? Can we wrap reactivity in a
component that has its own state? And where does the state live?

```ruby
class Counter < Syntropy::Component
  def initialize(start:, **props)
    @count = reactive()
  end

  def template
    div {
      h3 'Interactive island'
      p "The server supplied the initial value of #props[:start]}"
      div {
        button '-', on_click: -> { @count.value -= 1 }
        div @count.value
        button '+', on_click: -> { @count.value += 1 }
      }
    }
  end
end
```

Hmm, don't know if the complexity is worth it. It's an abstraction that's very
costly - both in terms of complexity of computation, and in terms of having a
clear mental model of what's happening under the hood.

I think a more logical approach is to stay with well-defined boundaries between
computation on the frontend and computation on the backend, and a having a clear
understanding of where things happen:

```ruby
class Counter < Syntropy::Component
  def incr
    update(value: @props[:value] + 1)
  end

  def decr
    update(value: @props[:value] - 1)
  end

  def template
    div {
      h3 'Interactive island'
      div {
        button '-', syn_click: 'decr'
        div @props[:value]
        button '+', syn_click: 'incr'
      }
    }
  end
end
```

Now, we can do all kinds of wrapping with scripts and ids and stuff to make this
work, but still, it would be preferable for the interactivity to be expressed in
JS. Maybe we just need a way to include a script that acts on the local HTML
code. How can we do this without writing a web component etc?

One way is to assign a random id to the template, then have a script that works
on it locally.

```ruby
export template { |**props|
  id = SecureRandom.hex(4)
  div(id: id) {
    h3 'Interactive island'
    div {
      button '-', syn_action: "decr"
      div props[:value], syn_value: "value"
      button '+', syn_action: "incr"
    }
    script <<~JS
      const state = { value: #{props[:value]} }
      const root = document.querySelector('##{id}')
      const decr = root.querySelector('[syn-action="decr"]')
      const incr = root.querySelector('[syn-action="incr"]')
      const value = root.querySelector('[syn-value="value"]')
      const updateValue = (v) => { state.value = v; value.innerText = String(v) }

      decr.addEventListener('click', (e) => { updateValue(state.value - 1) })
      incr.addEventListener('click', (e) => { updateValue(state.value + 1) })
    JS
  }
}
```

How can we make this less verbose, less painful, less error-prone?

One way is to say - we don't worry about this on the backend, we just write
normal JS for the frontend and forget about the whole thing. Another way is to
provide a set of tools for making this less painful:

- Add some fancier abstractions on top of the JS RPC lib
- Add some template extensions that inject JS into the generated HTML

## Testing facilities

- What do we need to test?
  - Routes
  - Route responses
  - Changes to state / DB
  - 

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
