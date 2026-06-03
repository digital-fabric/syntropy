@posts = import '/_lib/posts'
@layout = import '/_layout/default'

export http_methods

def get(req)
  req.respond_html(
    @template.render
  )
end

@template = @layout.apply { |**props|
  h1 "Create blog post"
  div {
    form(action: "/posts", method: 'post') {
      div {
        label 'Title', for: 'title'
        input name: 'title', type: 'text'
      }
      div {
        label 'Body', for: 'body'
        textarea '', name: 'body', rows: 5
      }
      div {
        button 'Submit', type: 'submit'
      }
    }
  }
}
