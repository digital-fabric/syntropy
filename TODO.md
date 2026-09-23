## Immediate

- Logging of errors - when normal (non-internal errors), the log record should include request info

## Logging

- Add optional SQLite-log store (+optional log viewing in Admin interface)

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
  Articles = @app.collection('_articles/*.md')
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
