export ->(req) {
  req.respond(nil, ':status' => HTTP::TEAPOT)
}
