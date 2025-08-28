export ->(req) {
  puts '*' * 40
  p req.route
  p req.route_params
  req.respond_on_get("#{req.route[:path]}-#{req.route_params['foo']}")
}
