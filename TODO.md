- Some standard middleware:

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

  def Syntropy
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




- CLI tool for setting up a site repo:

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

  - Some of the files might need templating, but we can maybe do without, or at
  least make it as generic as possible.

- `syntropy setup` steps:

  1. Verify existence of target directory
  2. Copy files from Syntropy template to target directory
  3. Do chmod +x for bin/*
  4. Do bundle install in the target directory
  5. Show some information with regard to how to get started working with the
     repo

- `syntropy provision` steps:

  1. Verify Ubuntu 22.x or higher
  2. Install git, docker, docker-compose

- `syntropy deploy` steps:

  1. Verify no uncommitted changes.
  2. SSH to remote machine.
    2.1. If not exists, clone repo
    2.2. Otherwise, verify remote machine repo is on same branch as local repo
    2.3. Do a git pull (what about credentials?)
    2.4. If gem bundle has changed, do a docker compose build
    2.5. If docker compose services are running, restart
    2.6. Otherwise, start services
    2.7. Verify service is running correctly
