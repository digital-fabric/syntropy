@post_store = import '_lib/post_store'
@layout = import '_layout/default'

export http_methods

def get(req)
  posts = @post_store.get_all
  req.respond_html(
    @template.render(posts:)
  )
end

def post(req)
  data = req.get_form_data
  title = req.validate(data['title'], String, /.+/)
  body = req.validate(data['body'], String, /.+/)
  id = @post_store.create(title, body)

  req.redirect("posts/#{id}")
end

@template = @layout.apply { |**props|
  h1 "My blog"
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
