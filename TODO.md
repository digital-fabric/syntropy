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
