## Immediate

- [ ] Nicer logging in development mode:

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

- [ ] Ability to load modules from builtin applet
  - [ ] Can we mount them on the app's module loader?

  Why we need that? The use case is making use of a default pub/sub instance  

- [ ] Pub/sub
  - [ ] Ruby side
  - [ ] JS side
  - [ ] Reimplement `auto_refresh` using a *default* event bus provided by
        Syntropy

- [ ] An alternative to the pub/sub design - add streaming responses to the
  JSON/jS API (using SSE).

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

- [ ] Improve serving of static files:
  - [ ] support for compression
  - [ ] add `Request#render_static_file(route, fn)

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
