@app.env[:setup_imported] = true

class << @app
  def foobar
    :foobar
  end
end
