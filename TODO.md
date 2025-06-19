## Server tool

```
$ bundle exec syntropy ./site
   ooo                                                 
  ooooo                                                
   ooo vvv       Syntropy - a web framework for Ruby   
    o vvvvv      -----------------------------------   
    |  vvv o                                           
  ::|:::|::|::   https://github.com/noteflakes/syntropy
  ++++++++++++

2025-06-18 19:19:03 { "level": "info", "ts": xxxxx, "msg": "yyyyy" }
...
```

Also maybe:

```bash
$ bundle exec syntropy --dev ./site
$ bundle exec syntropy --workers 4 ./site
```

And also a config file:

```bash
$ bundle exec syntropy site.rb
```

And the config file:

```ruby
# site.rb
Syntropy.config do
  root './site'
  workers 4
end
```

## Lightweight model API on top of Extralite

- DB connection pool
- Lightweight means 90% features with 10% effort:

```ruby
Posts = Syntropy::Relation.new('posts')

posts = Posts.order_by(:stamp, :desc).all(db)

post = Posts.where(id: 13).first(db)

id = Posts.insert(db, title: 'foo', body: 'bar')

Posts.where(id: id).update(db, body: 'baz')

Posts.where(id: id).delete(db)
```

The whole `db` argument thing is very limiting. For easier usage we integrate
the db connection pool as dependency injection the model:

```ruby
db_pool = E2::ConnectionPool.new(fn)
Posts = Syntropy::Relation.new(db_pool, 'posts')

Posts[id: 1] #=> { id: 1, title: 'foo', body: 'bar' }
Posts.find(id: 1) #=>

Posts.to_a #=> [...]
Posts.order_by(:stamp, :desc).to_a #=> [...]

id = Posts.insert(title: 'foo', body: 'bar')

post = Posts.where(id: id)
post.values #=> { id: 1, title: 'foo', body: 'bar' }
post.update(body: 'baz') #=> 1
post.delete
```

So basically it's a bit similar to Sequel datasets, but there's no "object instance as single row". The instance is the entire set of rows in the table, or a subset thereof:

```ruby
Posts.where(...).order_by(...).select(...).from(rowset)
```

How about CTEs?

```ruby
Users = Syntrop::Dataset.new(db_pool, 'users')

Syntropy::Rowset {
  with(
    foo: Users,
    bar: -> {
      select user_id, group
      from foo
    },
    baz: -> {
      select id
      from bar
      where user_id == bar.select(:user_id)
    }

}
  with(:foo) {
    select_all.from(:users)
  }.
  with(:bar) {
    select(:group).from(:foo)
  }.
  with(:baz) {
    select(:id).
    from(:bar).
    where(user_id: )
  }

```
