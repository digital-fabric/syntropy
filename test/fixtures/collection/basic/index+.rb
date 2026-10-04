begin
  @articles = collection('_articles', url_base: @url)
end

export ->(req) do
  if req.path == @url
    list = @articles.list.map { it[:ref] }
    req.respond_json(list)
  elsif (article = @articles.get(req.path))
    req.respond_json(article)
  else
    raise Error.not_found if !article
  end
end
