<h1 align="center">
  <br>
  Syntropy
</h1>

<h4 align="center">A Web Framework for Ruby</h4>

<p align="center">
  <a href="http://rubygems.org/gems/syntropy">
    <img src="https://badge.fury.io/rb/syntropy.svg" alt="Ruby gem">
  </a>
  <a href="https://github.com/digital-fabric/syntropy/actions">
    <img src="https://github.com/digital-fabric/syntropy/actions/workflows/test.yml/badge.svg" alt="Tests">
  </a>
  <a href="https://github.com/digital-fabric/syntropy/blob/master/LICENSE">
    <img src="https://img.shields.io/badge/license-MIT-blue.svg" alt="MIT License">
  </a>
</p>

## What is Syntropy?

| Syntropy: A tendency towards complexity, structure, order, organization of
ever more advantageous and orderly patterns.

Syntropy is a web framework for building multi-page and single-page apps.
Syntropy uses file tree-based routing, and provides controllers for a number of
common patterns, such as a SPA with client-side rendering, a standard
server-rendered MPA, a REST API etc.

Syntropy also provides tools for working with lists of items represented as
files (ala Jekyll and other static site generators), allowing you to build
read-only apps (such as a markdown blog) without using a database.

For interactive apps, Syntropy provides basic tools for working with SQLite
databases in a concurrent environment.

Syntropy is based on:

- [UringMachine](https://github.com/digital-fabric/uringmachine) - a lean mean
  [io_uring](https://unixism.net/loti/what_is_io_uring.html) machine for Ruby.
- [TP2](https://github.com/digital-fabric/tp2) - an io_uring-based web server for
  concurrent Ruby apps.
- [Qeweney](https://github.com/digital-fabric/qeweney) a uniform interface for
  working with HTTP requests and responses.
- [Papercraft](https://github.com/digital-fabric/papercraft) HTML templating with plain Ruby.
- [Extralite](https://github.com/digital-fabric/extralite) a fast and innovative
  SQLite wrapper for Ruby.

## Examples

To get a taste of some of Syntropy's capabilities, you can run the included
examples site inside the Syntropy repository:

```bash
$ cd syntropy
$ bundle exec syntropy -d examples
```

## Routing

Syntropy routes request by following the tree structure of the Syntropy app. A
simple example:

```
site/
├ _layout/
| └ default.rb
├ _articles/
| └ 2025-01-01-hello_world.md
├ api/
| ├ _hook.rb
| └ v1.rb
├ assets/
| ├ css/
| ├ img/
| └ js/
├ about.md
├ archive.rb
├ index.rb
└ robots.txt
```

Syntropy knows how to serve static asset files (CSS, JS, images...) as well as
render markdown files and run modules written in Ruby.

Some conventions employed in Syntropy-based web apps:

- Files and directories starting with an underscore, e.g. `/_layout` are
  considered private, and are not exposed to HTTP clients.
- Normally, a module route only responds to its exact path. To respond to any
  subtree path, add a plus sign to the end of the module name, e.g. `/api+.rb`.
- A `_hook.rb` module is invoked on each request routed to anywhere in the
  corresponding subtree. For example, a hook defined in `/api/_hook.rb` will be
  used on requests to `/api`, `/api/foo`, `/api/bar` etc.
- As a corollary, each route "inherits" all hooks defined up the tree. For
  example, a request to `/api/foo` will invoke hooks defined in `/api/_hook.rb`
  and `/_hook.rb`.
- In a similar fashion to hooks, error handlers can be defined for different
  subtrees in a `_error.rb` module. For each route, in case of an exception,
  Syntropy will invoke the closest-found error handler module up the tree. For
  example, an error raised while responding to a request to `/api/foo` will
  prefer the error handler in `/api/_error.rb`, rather than `/_error.rb`.
- The Syntrpy router accepts clean URLs for Ruby modules and Markdown files. It
  also accepts clean URLs for `index.html` files.

## Running Syntropy

Note: Syntropy runs exclusively on Linux and requires kernel version >= 6.4.

To start a web server on the working directory, use the `syntropy` command:

```bash
$ # install syntropy:
$ gem install syntropy
$ # run syntropy
$ syntropy path/to/my_site
```

To get help for the different options available, run `syntropy -h`.

## Development mode

When developing and making changes to your site, you can run Syntropy in
development mode, which automatically reloads changed modules and provides tools
to automatically refresh open web pages and debug HTML templates. To start
Syntropy in development mode, run `syntropy -d path/to/my_site`.

## What does a Syntropic Ruby module look like?

Consider `site/archive.rb` in the file tree above. We want to get a list of
articles and render it using the given layout:

```ruby
# archive.rb
@@layout = import('$layout/default')

def articles
  Syntropy.stamped_file_entries('/_articles')
end

export @@layout.apply(title: 'archive') {
  div {
    ul {
      articles.each { |article|
        li { a(article.title, href: article.url) }
      }
    }
  }
}
```

But a module can also be something completely different:

```ruby
# api/v1.rb
class APIV1 < Syntropy::JSONAPI
  def initialize(db)
    @db = db
  end

  # /posts
  def all(req)
    @db[:posts].order_by(:stamp.desc).to_a
  end

  def by_id(req)
    id = req.validate_param(:id, /^{4,32}$/)
    @db[:posts].where(id: id).first
  end
end

export APIV1
```

Basically, the exported value can be a template, a callable or a class that
responds to the request. Here's a minimal module that responds with a hello
world:

```ruby
export ->(req) { req.respond('Hello, world!') }
```

## Module Export / Import

Modules communicate with the Syntropy framework and with other modules using
`export` and `import`. Each module must export a single object, which can be a
controller class, a callable (a proc/closure) or a template. The exported object
is used by Syntropy as the entrypoint for the route.

But modules can also import other modules. This permits the use of layouts:

```ruby
# site/_layout/default.rb
export template { |**props|
  header {
    h1 'Foo'
  }
  content {
    render_yield(**props)
  }
}

# site/index.rb
layout = import '_layout/default'

export layout.apply { |**props|
  p 'o hi!'
}
```

A module can also be written as a set of methods without any explicit class
definition. This allows writing modules in a more functional style:

```ruby
# site/_lib/utils.rb

def foo
  42
end

export self

# site/index.rb
Utils = import '_lib/utils'

export template {
  h1 "foo = #{Utils.foo}"
}
```

## Hooks (a.k.a. Middleware)

A hook is a piece of code that can intercept HTTP requests before they are
passed off to the correspending route. Hooks are applied to the subtree of the
directory in which they reside.

Hooks can be used for a variety of purposes:

- Parameter validation
- Authentication, authorization & session management
- Logging
- Request rewriting / redirecting

When multiple hooks are defined up the tree for a particular route, they are
chained together such that each hook is invoked starting from the file tree root
and down to the route path.

Hooks are implemented as modules named `_hook.rb`, that export procs (or
callables) with the following signature:

```ruby
# **/_hook.rb
export ->(req, app) { ... }
```

... where req is the request object, and app is the callable that code. Here's
an example of an authorization hook:

```ruby
export ->(req, app) {
  if (!req.cookies[:session_id])
    req.redirect('/signin')
  else
    app.(req)
  end
}
```

## Error handlers

An error handler can be defined separately for each subtree. When an exception
is raised that is not rescued by the application code, Syntropy will look for an
error handler up the file tree, and will invoke the first error handler found.

Error handlers are implemented as modules named `_error.rb`, that export procs (or
callables) with the following signature:

```ruby
# **/_error.rb
->(req, err) { ... }
```

Using different error handlers for parts of the route tree allows different
error responses for each route. For example, the error response for an API route
can be a JSON object, while the error response for a browser page route can be a
custom HTML page.
