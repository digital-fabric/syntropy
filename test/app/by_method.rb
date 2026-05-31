export http_methods

def get(req)
  req.respond('foo')
end

def post(req)
  req.respond('bar')
end
