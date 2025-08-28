# frozen_string_literal: true

require_relative 'helper'

class ErrorsTest < Minitest::Test
  ISE = Qeweney::Status::INTERNAL_SERVER_ERROR

  def test_error_http_status_class_method
    e = RuntimeError.new
    assert_equal ISE, Syntropy::Error.http_status(e)

    e = Syntropy::Error.new
    assert_equal ISE, Syntropy::Error.http_status(e)

    e = Syntropy::Error.new(Qeweney::Status::UNAUTHORIZED)
    assert_equal Qeweney::Status::UNAUTHORIZED, Syntropy::Error.http_status(e)
  end

  def test_method_not_allowed_error
    e = Syntropy::Error.method_not_allowed('foo')
    assert_kind_of Syntropy::Error, e
    assert_equal Qeweney::Status::METHOD_NOT_ALLOWED, e.http_status
    assert_equal 'foo', e.message
  end

  def test_not_found_error
    e = Syntropy::Error.not_found('bar')
    assert_kind_of Syntropy::Error, e
    assert_equal Qeweney::Status::NOT_FOUND, e.http_status
    assert_equal 'bar', e.message
  end

  def test_validation_error
    e = Syntropy::ValidationError.new('baz')
    assert_equal Qeweney::Status::BAD_REQUEST, e.http_status
    assert_equal 'baz', e.message
  end
end
