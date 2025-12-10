# 0.27.8 2025-12-10

- Update UringMachine, TP2

# 0.27.7 2025-11-03

- Update UringMachine, TP2
- Optimize router generated code

# 0.27.6 2025-10-30

- Redirect automatically on trailing slash

# 0.27.5 2025-10-28

- Update Papercraft
- Fix backtrace display in error page
- Make auto_refresh, tag debug extensions noops when not in dev mode

# 0.27.4 2025-10-27

- Update dependencies

# 0.27.3 2025-10-23

- Do not log Not Found errors
- Fix handling of syntax error in module
- Update dependencies

# 0.27.2 2025-10-21

- Add `Module#collection_module!` method

# 0.27.1 2025-10-21

- Fix error instantiation and error testing

# 0.27 2025-10-21

- Use accept header (instead of user-agent) for rendering error page
- Add `Request#accept?` method
- Fix import path normalization, module method visibility
- Fix instantiation of Syntropy::Error
- Improve default error handler response
- Fix and enhance `Request#html_response`, `Request#json_response` methods

# 0.26 2025-10-21

- Add /.syntropy/req route for testing request headers
- Add default builtin error page / response
- Add `Request#browser?` method for detecting browser
- Change behaviour of import to support relative paths
- Update Papercraft

# 0.25 2025-10-19

- Upgrade Papercraft to version 3.0
- Fix tests

# 0.24 2025-10-08

- Use gem.coop in Gemfile
- Update Papercraft

# 0.23 2025-10-02

- Update dependencies

# 0.22 2025-09-29

- Fix `@ref` for index modules

# 0.21 2025-09-29

- Fix routing with wildcard `index+.rb` modules

# 0.20 2025-09-17

- Update Papercraft

# 0.19 2025-09-14

- Implement HTTP caching for static files
- Add `--no-server-headers` option
- Update TP2: server headers, injected response headers, cookies

# 0.18 2025-09-11

- Rename P2 back to Papercraft

# 0.17 2025-09-11

- Move repo to [digital-fabric](https://github.com/digital-fabric/syntropy)

# 0.16 2025-09-11

- `syntropy` script:
  - Remove trailing slash for root dir in syntropy script
  - Rename `-w/--watch` option to `-d/--dev` for development mode
  - Fix `--mount` option
- Add builtin `/.syntropy` applet for builtin features:
  - auto refresh for web pages
  - JSON API
  - Template debugging frontend tools
  - ping route
  - home page with links to examples
- Implement applet mounting and loading
- Remove Papercraft dependency
- Add support for Papercraft XML templates, using `#template_xml`
- Update Papercraft, TP2

# 0.15 2025-08-31

- Implement invalidation of reverse dependencies on module file change

# 0.14 2025-08-30

- Tweak "boot" sequence
- Update dependencies
- Log errors in App#call
- Improve module loading, add logging

# 0.13 2025-08-28

- Reimplement module loading
- Refactor RoutingTree

# 0.12 2025-08-28

- Add routing info to request: `#route`, `#route_params`
- Improve validations
- Improve errors
- Reimplement `App`
- Add support for parametric routes
- Reimplement `RoutingTree` (was `Router`)

## 0.11 2025-08-17

- Upgrade to Papercraft 2.8

## 0.10.1 2025-08-10

- Fix ModuleLoader.wrap_module to work correctly with Papercraft::Template

## 0.10 2025-08-10

- Add query, execute methods to ConnectionPool
- Switch from Papercraft to Papercraft

## 0.9.2 2025-07-24

- Fix logging

## 0.9.1 2025-07-08

- Update TP2

## 0.9 2025-07-08

- Update TP2
- Add `Module.app` method for loading arbitrary apps
- Set `Module@machine`

## 0.8.4 2025-07-07

- Update TP2
- Fix Router#path_parent to not break on double slash

## 0.8.3 2025-07-06

- Correctly handle HEAD requests for template modules

## 0.8.2 2025-07-06

- Update deps

## 0.8.1 2025-07-06

- Ignore site directories starting with underscore in `route_by_host`

## 0.8 2025-07-05

- Add `MODULE` constant for referencing the module
- Implement `Module.page_list`

## 0.7 2025-07-05

- Implement `Module.route_by_host`
- Add snoozing on DB progress

## 0.6 2025-07-05

- Add support for middleware and error handlers

## 0.5 2025-07-05

- Refactor App class to use Router
- Refactor routing functionality into separate Router class
- Add support for _site.rb file

## 0.4 2025-07-03

- Improve errors API
- Add HTTP method validation
- Refactor Qeweney::Request extensions
- Add side_run API for running tasks on a side thread
- Add support for rendering markdown with layout

## 0.3 2025-06-25

- Implement module reloading on file change

## 0.2 2025-06-24

- Add CLI tool
- Implement basic module loading
- Implement ConnectionPool

## 0.1 2025-06-17

- Move context inside Request object
- Implement routing
- Implement RPC API controller
- Implement Context with parameter validation
- Preliminary version
