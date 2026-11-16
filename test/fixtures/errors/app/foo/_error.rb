export ->(req, error) {
  req.respond("foo: #{error.message}", ':status' => Error.http_status(error))
}
