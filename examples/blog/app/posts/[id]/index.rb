@post_store = import '/_lib/post_store'
@layout = import '/_layout/default'

export http_methods

def get(req)
  id = req.route_params['id'].to_i
  post = @post_store.get(id)
  raise Syntropy::Error.not_found if !post

  req.respond_html(
    @template.render(post:)
  )
end

def post(req)
  id = req.route_params['id'].to_i
  data = req.get_form_data
  title = req.validate(data['title'], String, /.+/)
  body = req.validate(data['body'], String, /.+/)

  puts '*' * 40
  p(id:, title:, body:)

  updated = @post_store.update(id, title, body)
  raise BadRequestError, "Failed to update post" if updated != 1

  req.redirect "/posts/#{id}", Syntropy::HTTP::SEE_OTHER
end

def delete(req)
  id = req.route_params['id'].to_i

  deleted = @post_store.delete(id)
  raise BadRequestError, "Failed to delete post" if deleted != 1

  req.redirect "/posts", Syntropy::HTTP::SEE_OTHER
end

@template = @layout.apply { |post:, **props|
  h1 "My blog"
  div {
    h2 {
      a post[:title]
    }
    p post[:body]
  }
  p {
    a "Edit", href: "/posts/#{post[:id]}/edit"
  }
  p {
    a "Back", href: '/posts'
  }
}
