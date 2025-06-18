class API < Syntropy::RPCAPI
  def initialize
    @count = 0
  end

  def get(ctx)
    @count
  end

  def incr!(ctx)
    if ctx.request.path != '/test/api'
        raise Syntropy::Error.new(Qeweney::Status::TEAPOT, 'Teapot') 
    end

    @count += 1
  end
end

API.new
