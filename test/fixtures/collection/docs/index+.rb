@pages = collection('_pages', url_base: @url)

export ->(req) do
  if req.path == @url
    list = @articles.list.map { it[:ref] }
    req.respond_json(list)
  elsif (page = @pages.get(req.path))
    if page[:type] == :directory
      req.respond_json(page.slice(:type, :title))
    else
      req.respond_json(page.slice(:type, :title, :body))
    end
  else
    raise Error.not_found if !article
  end
end
