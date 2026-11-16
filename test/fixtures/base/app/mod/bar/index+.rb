export self

def env
  @env
end

def call(req)
  req.respond_json({ rel_path: req.route_params[:__rel_path__]})
end
