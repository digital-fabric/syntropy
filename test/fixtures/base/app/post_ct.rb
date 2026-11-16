export dispatch_by_http_method

def post(req)
  req.respond("#{req.content_type}:#{req.read}")
end
