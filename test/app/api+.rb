class API < Syntropy::RPCAPI
  def initialize(env)
    super(env)
    @count = 0
  end

  def get(req)
    @count
  end

  def incr!(req)
    if req.path != '/test/api'
        raise Syntropy::Error.new(Qeweney::Status::TEAPOT, 'Teapot')
    end

    @count += 1
  end

  def req(req)
    { query: req.query, headers: req.headers }
  end
end

export API
