export ->(req) {
  req.respond_on_get("#{req.route[:path]}-#{req.route_params['foo']}")
}
