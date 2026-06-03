# frozen_string_literal: true

export ->(req) {
  req.respond('hi', ':status' => HTTP::TEAPOT)
}
