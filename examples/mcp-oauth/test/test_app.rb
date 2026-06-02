# frozen_string_literal: true

class AppTest < Syntropy::Test
  def test_root
    req = get('/')
    assert_equal HTTP::OK, req.response_status
    assert_match /Syntropy/, req.response_body
  end
end
