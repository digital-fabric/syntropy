# My awesome Syntropy app

## Installation

```bash
$ bundle install
```

## Running the web server

```bash
$ bundle exec syntropy serve
```

## Starting the app console

```bash
$ bundle exec syntropy console
```

### Running tests

```bash
$ bundle exec syntropy tests
```

### Usage with Docker Compose

You can also run the app on Docker Compose:

```bash
# run the app server
$ docker compose up

# run the console
$ docker compose run --remove-orphans console

# run tests
$ docker compose run --remove-orphans test
```
