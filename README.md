<h1 align="center">
  <br>
  Syntropy
</h1>

<h4 align="center">A Web Framework for Ruby</h4>

<p align="center">
  <a href="http://rubygems.org/gems/syntropy">
    <img src="https://badge.fury.io/rb/syntropy.svg" alt="Ruby gem">
  </a>
  <a href="https://github.com/noteflakes/syntropy/actions">
    <img src="https://github.com/noteflakes/syntropy/actions/workflows/test.yml/badge.svg" alt="Tests">
  </a>
  <a href="https://github.com/noteflakes/syntropy/blob/master/LICENSE">
    <img src="https://img.shields.io/badge/license-MIT-blue.svg" alt="MIT License">
  </a>
</p>

## What is Syntropy?

| Syntropy: A tendency towards complexity, structure, order, organization of
ever more advantageous and orderly patterns.

Syntropy is a WIP web framework for building multi-page and single-page apps.
Syntropy uses file tree-based routing, and provides controllers for a number of
common patterns, such as a SPA with client-side rendering, a standard
server-rendered MPA, a REST API etc.

## Routing

Routing is performed automatically by following the tree structure of the
Syntropy app. A simple example:

```
site/
├ _layout/
| └ default.rb
├ _articles/
| └ 2025-06-01-hello_world.md
├ api/
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

The routing follows the file hierarchy, and Syntropy knows how to serve static
asset files (CSS, JS, images...) as well as render markdown files and run custom
Ruby code.

## What does a Syntropic Ruby module look like?

Consider `archive.rb` in the example above. We want to get a list of articles
and render it with the given layout:

```ruby
# archive.rb
@@layout = import('$layout/default')

def articles
  Syntropy.stamped_file_entries('/_articles')
end

@@layout.apply(title: 'archive') {
  div {
    ul {
      articles.each { |article|
        li { a(article.title, href: article.url) }
      }
    }
  }
}
```

But a module can be something completely different:

```ruby
# api/v1.rb
class APIV1 < Syntropy::RPCAPI
  def initialize(db)
    @db = db
  end

  # /posts
  def all(ctx)
    @db[:posts].order_by(:stamp.desc).to_a
  end

  def by_id(ctx)
    id = ctx.validate_param(:id, /^{4,32}$/)
    @db[:posts].where(id: id).first
  end
end

APIV1.new(Syntropy.env.open_db)
```

Basically, the return value of the module is a template or a resource that
responds to the request.