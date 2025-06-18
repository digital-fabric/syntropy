class API < Syntropy::RPCAPI
  def initialize
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
end

API.new
