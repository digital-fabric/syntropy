# frozen_string_literal: true

require 'fileutils'
require_relative 'helper'

class FileWatchTest < Minitest::Test
  def setup
    @machine = UM.new
    @root = "/tmp/syntropy/#{rand(1000000).to_s(16)}"
    FileUtils.mkdir_p(@root)
  end

  def test_file_watch
    queue = UM::Queue.new

    f = @machine.spin do
      Syntropy.file_watch(@machine, @root, period: 0.01) { |event, fn| @machine.push(queue, [event, fn]) }
    end
    @machine.sleep(0.05)
    assert_equal 0, queue.count

    fn = File.join(@root, 'foo.bar')
    IO.write(fn, 'abc')
    assert_equal [:added, fn], @machine.shift(queue)

    fn = File.join(@root, 'foo.bar')
    IO.write(fn, 'def')
    assert_equal [:modified, fn], @machine.shift(queue)

    FileUtils.rm(fn)
    assert_equal [:removed, fn], @machine.shift(queue)
  ensure
    @machine.schedule(f, UM::Terminate)
    # @machine.join(f)
  end
end
