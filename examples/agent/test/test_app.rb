# frozen_string_literal: true

class AppTest < Syntropy::Test
  def test_routing
    req = get('/')
    assert_equal HTTP::OK, req.response_status

    req = get('/test')
    assert_equal HTTP::OK, req.response_status

    req = get('/foo')
    assert_equal HTTP::NOT_FOUND, req.response_status
  end
end
