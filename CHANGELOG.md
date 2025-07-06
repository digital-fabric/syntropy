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
