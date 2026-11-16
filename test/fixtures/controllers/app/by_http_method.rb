export dispatch_by_http_method

def get(req)
  req.respond('get')
end

def post(req)
  req.respond('post')
end
