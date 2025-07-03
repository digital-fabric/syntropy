- Middleware

  ```Ruby
  # site/_middleware.rb or site/_hook.rb
  export ->(req, &app) do
    app.call(req)
  rescue Syntropy::Error => e
    render_error_page(req, e.http_status)
  end

  # an alternative, at least for errors is a _error.rb file:
  # site/_error.rb
  # Just a normal callable:
  #
  export ->(req, err) do
    render_error_page(req, err.http_status)
  end
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
