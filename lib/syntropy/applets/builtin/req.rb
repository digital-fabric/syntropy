# frozen_string_literal: true

export ->(req) {
  req.respond_json({
    headers: req.headers
  })
}
