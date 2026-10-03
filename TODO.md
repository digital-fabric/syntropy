## Extralite doc site

- Similar to Papercraft site
- Replace `collection_module!` with something more flexible, just add watching
  for directories:

  ```ruby
  # proposed API:
  invalidate_on_file_change('_pages/**/*')

  # implementation
  def invalidate_on_file_change(pattern)
    @module_loader.invalidate_on_file_change(pattern, @ref)
  end

  class ModuleLoader
    def invalidate_on_file_change(pattern, mod_ref)
      @invalidation_patterns ||= Hash.new { |h, k| h[k] = [] }
      @invalidation_patterns[pattern] << mod_ref
    end

    def invalidate(ref)
      ...
      invalidated_refs = Set.new
      @invalidation_patterns.each { |pat, ref|
        invalidated_refs << ref if File.fnmatch(pat, ref)
      }
      invalidated_refs.each { invalidate(ref) }
    end
  end
  ```

- Implement collection with code from papercraft.noteflakes.com
- Further take ideas from discussion below
- Implement auto light/dark CSS theme
- Write docs

## Collections - some new thoughts

What's the desired API?

```ruby
@articles = collection(
  root: '/_articles',
  url_base: @ref
)

export ->(req) {
  article = @articles.find(req.path)
  raise Syntropy::Error.not_found

  respond_html(@template.render(article))
}

## show list of articles:
->(req) {
  list = @articles.list('*')
  respond_html(@template.render(list))
}
```

How are collection items represented?

```ruby
item = {
  fn:, rel_path:, url:, type:, ...
}

# where type is one of
types = [ :markdown, :json]

# a markdown item
item = {
  fn:, rel_path:, url:, type:, attributes:, body:
}

# a JSON item
item = {
  fn:, rel_path:, url:, type:, value:
}
```


  # there should also be methods for creating, updating and deleting of
  # articles/items.
  
```


## Logging

- Make it possible to use different logger implementations, or maybe chain
  multiple logger implementations, such that we could emit for example both to
  STDOUT and to a database.
- Add optional SQLite-log store (+optional log viewing in Admin interface)

## Nicer logging in development mode:

Nice terminal formatting with colors:

```
sharon@nf1:~/tmp/capatest2$ npx serve dist

   ┌───────────────────────────────────────────┐
   │                                           │
   │   Serving!                                │
   │                                           │
   │   - Local:    http://localhost:3000       │
   │   - Network:  http://192.168.0.106:3000   │
   │                                           │
   │   Copied local address to clipboard!      │
   │                                           │
   └───────────────────────────────────────────┘

 HTTP  7/6/2026 8:04:23 PM 127.0.0.1 GET /
 HTTP  7/6/2026 8:04:23 PM 127.0.0.1 Returned 200 in 42 ms
 HTTP  7/6/2026 8:04:23 PM 127.0.0.1 GET /assets/index-edfizW3i.js
 HTTP  7/6/2026 8:04:23 PM 127.0.0.1 GET /assets/index-PVjztr5e.css
 HTTP  7/6/2026 8:04:23 PM 127.0.0.1 Returned 200 in 3 ms
 HTTP  7/6/2026 8:04:23 PM 127.0.0.1 Returned 200 in 12 ms
 HTTP  7/6/2026 8:04:23 PM 127.0.0.1 GET /assets/p-Sh0ICmPV-D227nRX-.js
 HTTP  7/6/2026 8:04:23 PM 127.0.0.1 Returned 200 in 3 ms
 HTTP  7/6/2026 8:04:23 PM 127.0.0.1 GET /assets/p-C4t5ymfq-4gquBJ2r.js
 HTTP  7/6/2026 8:04:23 PM 127.0.0.1 Returned 200 in 6 ms
 HTTP  7/6/2026 8:04:23 PM 127.0.0.1 GET /assets/p-D6Ynv7Xh-CRAF8up3.js
 HTTP  7/6/2026 8:04:23 PM 127.0.0.1 Returned 200 in 4 ms
^C
 INFO  Gracefully shutting down. Please wait...
```

```
sharon@nf1 ~/ $ be syntropy serve

   ooo
  ooooo
   ooo vvv       Syntropy - a web framework for Ruby
    o vvvvv      --------------------------------------
    |  vvv o    https://github.com/digital-fabric/syntropy
   :|:::|::|:
++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

2026-06-07 08:04:23 <== GET /
2026-06-07 08:04:23 ==> 200 (42ms)
2026-06-07 08:04:23 <== GET /assets/index-edfizW3i.js
2026-06-07 08:04:23 <== GET /assets/index-PVjztr5e.css
2026-06-07 08:04:23 ==> 200 (3ms)
2026-06-07 08:04:23 ==> 200 (12ms)

```

Verbose output (`-v`):

```
2026-06-07 08:04:23 <== GET /
  Host: localhost:3000
  User-Agent: ...
  Cookie: ...
  Accept: ...
2026-06-07 08:04:23 ==> 200 (42ms)
  Server: syntropy
  Transfer-Encoding: chunked
  ...
2026-06-07 08:04:23 <== GET /assets/index-edfizW3i.js
  ...
2026-06-07 08:04:23 <== GET /assets/index-PVjztr5e.css
  ...
2026-06-07 08:04:23 ==> 200 (3ms)
  ...
2026-06-07 08:04:23 ==> 200 (12ms)
  ...
```

## Background jobs

- Backed by SQLite db
- Recurring jobs
- Scheduled jobs
- Retries
- CLI command `syntropy background`
- Run automatically when running `syntropy serve` in dev mode

## Admin Dashboard

- Server state / stats
- Background jobs state / stats
- For resources:

  ```ruby
  # /app/admin+.rb
  export admin_ui(
    resources: {
      posts: {
        type: 'crud',
        module: '/storage/posts',
        primary_key: :id,
        editor_fields: {
          id: hidden
          title: text,
          body: textarea
        },
        actions: {
          list:  ->(s) { s.list() },
          list: 
        }
      }
    }
  )
  ```

  Or, maybe:

  ```ruby
  # /app/admin/index.rb
  Admin = import '/admin/.controller'
  export Admin.homepage


  # /app/admin/.controller.rb
  require 'syntropy/admin'
  export Syntropy::Admin.new(
    # config
  )


  # /app/admin/resources/posts.rb
  Admin = import '/admin/.controller'
  Posts = import '/storage/posts'

  Resource = Admin.resource(
    name: 'Posts',
    fields: {
      id: hidden
      title: text,
      body: textarea
    }
  )
  export Resource.controller

  def list(req)
    list = Posts.list
  end
  
    actions: {
      list:  ->(s) { s.list() },
      list: 
    }
  )
  ```


# Pub/sub

- [ ] Ability to load modules from builtin applet
  - [ ] Can we mount them on the app's module loader?

  Why we need that? The use case is making use of a default pub/sub instance  

- [ ] Pub/sub
  - [ ] Ruby side

  ```ruby
  @firehose = @app.import('/.syntropy/firehose')

  def on_change(v)
    @firehose.publish({ kind: 'value_changed', value: v })
  end

  ## in a pub/sub controller
  @firehose = @app.import('/.syntropy/firehose')

  def call(req)
    @firehose.stream_sse(req)
  end
  ```

  - [ ] JS side

  ```javascript
  await window.syntropy.firehose.process(async (evt, next) => {
    if (evt.kind == 'value_changed')
      await valueChanged(evt.value)
    else if (next)
      await next(evt);
  });
  ```

  - [ ] Reimplement `auto_refresh` using a *default* event bus provided by
        Syntropy

- [ ] An alternative to the pub/sub design - add streaming responses to the
  JSON/jS API (using SSE).

## Scaffolding

In rails, you can generate specific parts of the app, like a model or a
controller, or a whole set of model, view, controller code for a given entity
(scaffolding.)

Does this make sense for Syntropy? The different kinds of code generated:

- a model with CRUD methods for the given entity.
- a set of CRUD controllers (spread over multiple files).
- a set of CRUD views corresponding to the controller.
- a set of tests for model, controller, view.

But in fact they don't make much sense separately, except maybe for the model.
So we follow Rail's example and implement a code generator. This is especially
useful for working with controllers. Since the controller code is spread over
four files, this is not something trivial.

## Collections

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
  Articles = @app.collection(
    location: '_articles/*.md',
    url_base: @ref
  )
  article = Articles.last_by(&:date)

  article.title #=>
  article.date #=>
  article.layout #=>
  article.render_proc #=> (load layout, apply article)
  article.render #=> (render to HTML)

  # there should also be methods for creating, updating and deleting of
  # articles/items.
  ...
  ```


## Missing for a first public release

- [ ] Logo
- [ ] Website
- [v] Frontend part of JSON API
- [v] Auto-refresh page when file changes
- [v] Examples
  - [v] Reactive app - counter or some other simple app showing interaction with
    server
  - [v] blog

## Testing facilities

- What do we need to test?
  - [v] Routes
  - [v] Route responses
  - [v] Changes to state / DB
  - [ ] Rendered HTML - presence of certain markup / elements / text

## Support for applets

- can be implemented as separate gems
- can route requests to a different directory (i.e. inside the gem directory)
- simple way to instantiate and setup the applet
- as a first example, implement an auth/signin applet:
  - session hook
  - session persistence
  - login page
  - support for custom behaviour and custom workflows (2FA, signin using OTP
    etc.)

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

## Some more CLI commands

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

## Syntropy Flow - Live Templates

The idea is to have something that works like LiveView, but without WebSocket.
Instead, we'll use SSE in conjunction with a controller URL that provides both
updates (through SSE), and receives user interaction from the browser with POST
requests.

The compiler needs to be able to compile:

- The HTML
- The initial update tree (statics + dynamics)
- Updated dynamic values

Supposing that the HTML and the initial update tree are rendered at once. Let's
say we have the following template:

```ruby
->(name:) {
  html {
    head { title "My live page" }
    body {
      p "Hello, #{name}!"
    }
  }
}
```

Which normally compiles to:

```ruby
->(__buffer__, name:) {
  __buffer__
    .<<("<!DOCTYPE html><html><head><title>My live page</title></head><body><p>")
    .<<(ERB::Escape.html_escape(("Hello, #{name}!")))
    .<<("</p></body></html>")
  __buffer__
}
```

A live template would look something like:

```ruby
# __flow_url__ is the URL used for the SSE connection, it includes an id for the
# specific connection.
initial = ->(__flow_url__, name:) {
  __html__ = +''
  __static__ = []; __dynamic__ = {}; __dynamic_counter__ = 0;
  
  __html__
    .<<(
      s = "<!DOCTYPE html><html><head><title>My live page</title></head><body><p>"
      __static__ << s
      s
    )
    .<<(
      s = ERB::Escape.html_escape(("Hello, #{name}!"))
      __dynamic__[__dynamic_counter__] = s
      __dynamic_counter__ += 1
      s
    )
    .<<(
      s = "</p></body><script src=\"#{__flow_url__}\"></script></html>"
      __static__ << s
      s
    )
  {
    html: __html__,
    update_tree = {
      s: __static__,
      d: __dynamic__
    }
  }
}
```

The controller would look something like:

```ruby
@template = import '/views/hello_world'

export flow_controller do
  def setup
    assigns[:name] = 'world'
    assigns[:counter] ||= 1
    @updater = @machine.spin {
      @machine.periodically(3) {
        assigns[:name] = "world (#{assignes[:counter] += 1})"
      }
    }
  end

  def teardown
    @machine.cancel(@updater)
  end
end
```

The flow_controller can handle four kinds of requests:

- `GET /hello` - This is the initial render, where it will:
  - generate a unique flow id which will be embedded in a flow url (see below)
  - render `initial` compiled template, and store the update tree in a short
    term hash (which is evacuated periodically for failed connections)
  - respond with the HTML
- `GET /hello?flow=setup` - The JS payload to start the SSE connection
  - boilerplate code for setting up the SSE connection
  - include inline the initial update tree containing static and dynamic parts
- `GET /hello?sse&fid=xxxx` - the SSE long-running connection, on which
  updates are sent. The flow id identifies the flow session, which permits
  reconnection in case of comm error. On connection, the controller will emit an
  initial update with the update tree (see below).

- `POST /hello?fid=xxxx` - for responding to user interaction.

Whenever a value in `assigns` changes, the *update* template is rerendered.
Here's how the compiled update template looks:

```ruby
initial = ->(name:) {
  __dynamic__ = {}; __dynamic_counter__ = 0;
  
  s = ERB::Escape.html_escape(("Hello, #{name}!"))
  __dynamic__[__dynamic_counter__] = s
  __dynamic_counter__ += 1

  __dynamic__
}
```

So, the initial update for this template will look something like the following:

```json
{
  s: [
    "<!DOCTYPE html><html><head><title>My live page</title></head><body><p>",
    "</p></body><script src=\"/hello?sse&fid=12345678\"></script></html>"
  ],
  d: {
    0: "world"
  }
}
```

Subsequent updates will look like:

```json
{
  d: {
    0: "world (10:27:32)"
  }
}
```

On the client side, each time an update is received on the SSE connection, it
includes the dynamic values. Those are diffed against the previous values, the
entire page HTML is zipped from the static and dynamic parts, and then morphdom
is used to patch the DOM with the relevant changes.
