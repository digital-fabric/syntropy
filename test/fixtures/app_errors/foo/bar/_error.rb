export ->(req, error) {
  req.respond("bar: #{error.message}", ':status' => Error.http_status(error))
}
