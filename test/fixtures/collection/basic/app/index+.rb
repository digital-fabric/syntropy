begin
  @articles = collection('_articles', url_base: @url)
rescue => e
  p e
  p e.backtrace
  exit!
end

export ->(req) do
  if req.path == @url
    list = @articles.list.map { it[:ref] }
    req.respond_json(list)
  elsif (article = @articles.get(req.path))
    o = article.slice(:fn, :ref, :url, :type, :attributes, :body)
    req.respond_json(o)
  else
    raise Error.not_found if !article
  end
rescue => e
  p e
  p e.backtrace
  exit!
end
