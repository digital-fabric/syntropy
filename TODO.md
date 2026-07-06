## Immediate

- [ ] If a module doesn't have an explicit export, it exports itself
  - [ ] No error for a module without an export

- [ ] Ability to load modules from builtin applet

  Why we need that? The use case is making use of a default pub/sub instance  

- [ ] Can we mount them on the app's module loader?

- [ ] Pub/sub
  - [ ] Ruby side
  - [ ] JS side
  - [ ] Reimplement `auto_refresh` using a *default* event bus provided by
        Syntropy

- [ ] An alternative to the pub/sub design - add streaming responses to the
  JSON/jS API (using SSE).

  ```ruby
  export ->(req)
  ```

## Model layer based on prepared queries

Usage:

```ruby
# application code:
post_id = Posts.insert(title:, content:)
Posts.add_tags(post_id:, tags: %w{foo bar})

# /_lib/models/posts.rb
class Posts < Syntropy::Store
  queries[:create] = 
    args(:title, :content)
    .validate(:title, String, /.{3,}/, message: "Post title must be at least 3 characters long")
    .validate(:content, String, /.+/, message: "Post content must not be empty")
    .query_single_value <<~SQL
      insert into posts (title, content)
      values (:title, :content)
      returning id
    SQL

  # Or, if we had something a bit more sophisticated:
  queries[:create] = ->(title:, content:) {
    validate(title, String, /.{3,}/, message: "Post title must be at least 3 characters long")
    validate(:content, String, /.+/, message: "Post content must not be empty")
    query_single_value(<<~SQL)
      insert into posts (title, content)
      values (:title, :content)
      returning id
    SQL
  }

  # This is *compiled* into:
  query[:create] = ->(title: content:) {
    validate(title, String, /.{3,}/, message: "Post title must be at least 3 characters long")
    validate(:content, String, /.+/, message: "Post content must not be empty")
    @__create__ ||= prepare_splat <<~SQL
      insert into posts (title, content)
      values (:title, :content)
      returning id
    SQL
    run_query_single_row(@__create__, title:, content:)
    # with_db { it[@__create__].bind(title:, content:).next }
  }


  # Now something with a transform
  queries[:all_posts_with_tags] = ->() {
    t = transform {
      id: integer.identity, title: text, content: text, tags: [{
        id: integer.identity, name: text
      }]
    }
    query(t, <<~SQL)
      select posts.id, posts.title, posts.content, tags.id, tags.name
      from posts
      left join posts_tags on posts.id = posts_tags.post_id
      left join tags on tags.id = posts_tags.tag_id
    SQL
  }

  # Compiled into:
  queries[:all_posts_with_tags] = ->() {
    @__all_posts_with_tags_t__ ||= transform {
      id: integer.identity, title: text, content: text, tags: [{
        id: integer.identity, name: text
      }]
    }
    @__all_posts_with_tags__ ||= prepare @__all_posts_with_tags_t__, <<~SQL
      select posts.id, posts.title, posts.content, tags.id, tags.name
      from posts
      left join posts_tags on posts.id = posts_tags.post_id
      left join tags on tags.id = posts_tags.tag_id
    SQL
    run_query(@__all_posts_with_tags__)
    # with_db { it[@__create__].bind(title:, content:).to_a }
  }

  # Eventually, we might have some DSL for expressing SQL:
  queries[:all_posts_with_tags] = ->() {
    t = transform {
      id: integer.identity, title: text, content: text, tags: [{
        id: integer.identity, name: text
      }]
    }
    query(t) {
      select posts.id, posts.title, posts.content, tags.id, tags.name
      from posts
      left_join posts_tags, on: posts.id == posts_tags.post_id
      left_join tags,       on: tags.id == posts_tags.tag_id
    }
  }

  queries[:create] = ->(title:, content:) {
    validate(title, String, /.{3,}/, message: "Post title must be at least 3 characters long")
    validate(:content, String, /.+/, message: "Post content must not be empty")
    query_single_value {
      insert_into posts(title, content)
      values :title, :content
      returning id
    }
  }
end
```

But maybe we don't need all that magic. How about just normal methods:

```ruby
# _lib/models/posts.rb
Storage = import '/_lib/storage'
CONN_POOL = Storage.connection_pool

# @return [Integer] post id
def create(title:, content:)
  validate_post_data(title:, content:)
  @__create__ ||= Storage.prepare_splat <<~SQL
    insert into posts (title, content)
    values (:title, :content)
    returning id
  SQL
  @__create__.get_single_row(CONN_POOL, title:, content:)
end

POSTS_TAGS_TRANSFORM = Extralite::Transform.new {
  {
    id: integer.identity, title: text, content: text, tags: [{
      id: integer.identity, name: text
    }]
  }
}

def all_with_tags
  @__all_posts_with_tags__ ||= Storage.prepare @__all_posts_with_tags_t__, <<~SQL
    select posts.id, posts.title, posts.content, tags.id, tags.name
    from posts
    left join posts_tags on posts.id = posts_tags.post_id
    left join tags on tags.id = posts_tags.tag_id
  SQL
  run_query(@__all_posts_with_tags__)

```

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
- [ ] SQLite database capabilities
  - [ ] Stores
    - [ ] KV store (with TTL)
- [v] Examples
  - [v] Reactive app - counter or some other simple app showing interaction with
    server
  - [ ] blog

## Testing facilities

- What do we need to test?
  - Routes
  - Route responses
  - Changes to state / DB
  - Rendered HTML - presence of certain markup / elements / text

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
