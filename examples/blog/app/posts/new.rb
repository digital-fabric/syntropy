@posts = import '/_lib/posts'
@layout = import '/_layout/default'

export dispatch_by_http_method

def get(req)
  req.respond_html(
    @template.render(req:)
  )
end

@template = @layout.apply { |req:, **props|
  h1 "Create blog post"
  div {
    form(action: req.rel(".."), method: 'post') {
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
