export ->(req) {
  req.respond(nil, ':status' => Status::TEAPOT)
}
