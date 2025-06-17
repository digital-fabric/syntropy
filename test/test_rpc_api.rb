# frozen_string_literal: true

require_relative 'helper'

class RPCAPITest < Minitest::Test
  def test_kernel_version
    v = UringMachine.kernel_version
    assert_kind_of Integer, v
    assert_in_range 600..700, v
  end
end