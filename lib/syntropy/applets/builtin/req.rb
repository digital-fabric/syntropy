# frozen_string_literal: true

export ->(req) {
  req.json_response({
    headers: req.headers
  })
}
