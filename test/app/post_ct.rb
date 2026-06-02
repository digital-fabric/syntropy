export http_methods

def post(req)
  req.respond("#{req.content_type}:#{req.read}")
end
