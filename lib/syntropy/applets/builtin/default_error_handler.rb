# frozen_string_literal: true

ErrorPage = ->(error:, status:, backtrace:) {
  html {
    head {
      title "Syntropy error: #{error.message}"
      meta charset: 'utf-8'
      meta name: 'viewport', content: 'width=device-width, initial-scale=1.0'
      link rel: 'stylesheet', type: 'text/css', href: '/.syntropy/default_error_handler/style.css'
    }
    body {
      div {
        big status
        h2 error.message
        if backtrace
          p "Backtrace:"
          ul {
            backtrace.each {
              li {
                a(it[:entry], href: it[:url])
              }
            }
          }
        end
      }
      auto_refresh_watch!
    }
  }
}

def transform_backtrace(backtrace)
  backtrace.map do
    location = it.match(/^(.+:\d+):/)[1]
    { entry: it, url: "vscode://file/#{location}" }
  end
end

def error_response_html(req, error)
  status = Syntropy::Error.http_status(error)
  backtrace = transform_backtrace(error.backtrace)
  html = Papercraft.html(ErrorPage, error:, status:, backtrace:)
  req.html_response(html, ':status' => status)
end

def error_response_raw(req, error)
  status = Syntropy::Error.http_status(error)
  response = {
    class: error.class.to_s,
    message: error.message,
    backtrace: error.backtrace
  }
  req.json_pretty_response(response, ':status' => status)
end

export ->(req, error) {
  req.accept?('text/html') ?
    error_response_html(req, error) : error_response_raw(req, error)
}
