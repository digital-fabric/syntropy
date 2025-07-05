DEFAULT_STATUS = Qeweney::Status::INTERNAL_SERVER_ERROR

export ->(req, err) {
  status = err.respond_to?(:http_status) ? err.http_status : DEFAULT_STATUS
  req.respond("<h1>#{err.message}</h1>", ':status' => status, 'Content-Type' => 'text/html')
}
