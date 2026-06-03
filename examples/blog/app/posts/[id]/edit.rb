@posts = import '/_lib/posts'
@layout = import '/_layout/default'

export http_methods

def get(req)
  id = req.route_params['id'].to_i
  post = @posts.get(id)
  raise Syntropy::Error.not_found if !post

  req.respond_html(
    @template.render(post:)
  )
end

@template = @layout.apply { |post:, **props|
  h1 "Edit blog post"
  div {
    form(action: "/posts/#{post[:id]}", method: 'post') {
      div {
        label 'Title', for: 'title'
        input name: 'title', type: 'text', value: post[:title]
      }
      div {
        label 'Body', for: 'body'
        textarea post[:body], name: 'body', rows: 5
      }
      div {
        button 'Submit', type: 'submit'
      }
    }
  }
}
