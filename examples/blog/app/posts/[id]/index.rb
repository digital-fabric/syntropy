@posts = import '/_lib/posts'
@layout = import '/_layout/default'

export dispatch_by_http_method

def get(req)
  id = req.route_params['id'].to_i
  post = @posts.get(id)
  raise Syntropy::Error.not_found if !post

  req.respond_html(@template.render(post:, req:))
end

def post(req)
  data = req.get_form_data
  return delete(req) if data['method'] == 'delete'

  id = req.route_params['id'].to_i
  title = req.validate(data['title'], String, /.+/)
  body = req.validate(data['body'], String, /.+/)

  updated = @posts.update(id, title, body)
  raise BadRequestError, "Failed to update post" if updated != 1

  req.flash[:notice] = 'Post was successfully updated.'
  req.redirect "/posts/#{id}", Syntropy::HTTP::SEE_OTHER
end

def delete(req)
  id = req.route_params['id'].to_i

  deleted = @posts.delete(id)
  raise BadRequestError, 'Failed to delete post' if deleted != 1

  req.flash[:notice] = 'Post was successfully destroyed.'
  req.redirect '/posts', Syntropy::HTTP::SEE_OTHER
end

@template = @layout.apply { |post:, **props|
  h1 'My blog'
  p props[:req]&.flash[:notice], style: 'color: green'
  div {
    h2 {
      a post[:title]
    }
    p post[:body]
  }
  p {
    a 'Edit', href: 'edit'
    span '|'
    a 'Back to posts', href: '/posts'
  }
  div {
    form(method: 'post') {
      input type: 'hidden', name: 'method', value: 'delete'
      button 'Delete this post', name: 'delete', type: 'submit'
    }
  }
}
