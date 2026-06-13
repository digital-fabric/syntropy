@posts = import '_lib/posts'
@layout = import '_layout/default'

export dispatch_by_http_method

def get(req)
  posts = @posts.get_all
  req.respond_html(
    @template.render(posts:, req:)
  )
end

def post(req)
  data = req.get_form_data
  title = req.validate(data['title'], String, /.+/)
  body = req.validate(data['body'], String, /.+/)
  id = @posts.create(title, body)

  req.flash[:notice] = 'Post was successfully created.'
  req.redirect("posts/#{id}")
end

@template = @layout.apply { |**props|
  h1 "My awesome blog"
  p props[:req]&.flash[:notice], style: 'color: green'
  props[:posts].each { |post|
    div {
      h2 {
        a post[:title], href: "/posts/#{post[:id]}"
      }
      p post[:body]
    }
  }

  div {
    p {
      a "New post", href: '/posts/new'
    }
  }
}
