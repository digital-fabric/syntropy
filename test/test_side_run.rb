# frozen_string_literal: true

require_relative 'helper'

class SideRunTest < Minitest::Test
  def setup
    @machine = UM.new
  end

  def test_side_run
    x = Syntropy::SideRun.call(@machine) { 42 }
    assert_equal 42, x

    hits = []
    f = @machine.spin {
      @machine.periodically(0.01) { hits << it }
    }

    y = Syntropy::SideRun.call(@machine) { sleep 0.10; 43 }
    @machine.schedule(f, UM::Terminate.new)
    assert_in_range 9..11, hits.size
  end

  class Bad < Exception
  end

  def test_side_run_exception
    assert_raises(Bad) { Syntropy::SideRun.call(@machine) { raise Bad } }
  end

  def test_side_run_convenience_method
    x = Syntropy.side_run(@machine) { 42 }
    assert_equal 42, x

    assert_raises(Bad) { Syntropy.side_run(@machine) { raise Bad } }
  end
end
