export dispatch_by_http_method

def get(req)
  req.respond('foo')
end

def post(req)
  req.respond('bar')
end

def put(req)
  req.respond_html('baz')
end
