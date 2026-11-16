export ->(req, error) {
  req.respond("root: #{error.message}", ':status' => Error.http_status(error))
}
