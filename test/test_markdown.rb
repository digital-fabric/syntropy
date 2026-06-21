# frozen_string_literal: true

require_relative 'helper'
require 'securerandom'

class MarkdownParseTest < Minitest::Test
  def test_markdown_parse_md
    md = <<~MD
      ---
      foo: bar
      ---
      foo *bar*
    MD

    h = {}
    atts, md2 = Syntropy::Markdown.parse_md(h, md)

    assert_equal h, atts
    assert_equal({ foo: 'bar' }, atts)
    assert_equal "foo *bar*\n", md2
  end

  def test_markdown_parse_file
    FileUtils.mkdir_p('/tmp/test')
    name = "2008-06-14-test-#{SecureRandom.hex(8)}"
    path = "/tmp/test/#{name}.md"
    IO.write(
      path,
      <<~MD
        ---
        bar: baz
        ---
        bar *baz*
      MD
    )

    env = { app_root: '/' }
    atts, md = Syntropy::Markdown.parse_file(path, env)
    assert_equal "/tmp/test/#{name}", atts[:url]
    assert_equal 'baz', atts[:bar]
    assert_equal "bar *baz*\n", md

    env = { app_root: '/tmp' }
    atts, md = Syntropy::Markdown.parse_file(path, env)
    assert_equal "/test/#{name}", atts[:url]
    assert_equal 'baz', atts[:bar]
    assert_equal "bar *baz*\n", md
  end
end

class MarkdownControllerTest < Minitest::Test
  HTTP = Syntropy::HTTP

  def setup
    @machine = UM.new
    @root = File.join(__dir__, 'fixtures/app')
    @env = { app_root: @root, machine: @machine }
    @env[:module_loader] = Syntropy::ModuleLoader.new(@env)

    @controller = nil
    @test_harness = Syntropy::TestHarness.new(->(req) { @controller.(req) })
  end
  
  def test_markdown_renderer_no_layout
    md = <<~MD
      foo *bar*
    MD

    atts = { foo: 'bar', title: 'Title' }

    @controller = Syntropy::Markdown.make_controller(@env, atts, md)
    req = @test_harness.request(':method' => 'GET', ':path' => '/')

    assert_equal HTTP::OK, req.response_status
    assert_equal(
      "<!DOCTYPE html><html><head><title>Title</title></head><body><p>foo <em>bar</em></p>\n</body></html>",
      req.response_body
    )
  end

  def test_markdown_renderer_with_layout
    src = <<~MD
      ---
      layout: kuku
      ---
      ## Bar
    MD

    atts, md = Syntropy::Markdown.parse_md({}, src)
    assert_equal 'kuku', atts[:layout]

    @controller = Syntropy::Markdown.make_controller(@env, atts, md)
    req = @test_harness.request(':method' => 'GET', ':path' => '/')

    assert_equal HTTP::OK, req.response_status
    assert_equal(
      "<header><h1>Kuku</h1></header><content><h2 id=\"bar\">Bar</h2>\n</content>",
      req.response_body
    )
  end

  def test_markdown_renderer_with_missing_module_loader
    src = <<~MD
      ---
      layout: kuku
      ---
      ## Bar
    MD

    @env[:module_loader] = nil
    atts, md = Syntropy::Markdown.parse_md({}, src)
    assert_equal 'kuku', atts[:layout]

    @controller = Syntropy::Markdown.make_controller(@env, atts, md)
    assert_raises(Syntropy::Error) {
      req = @test_harness.request(':method' => 'GET', ':path' => '/')
    }
  end

  def test_markdown_renderer_with_invalid_layout
    src = <<~MD
      ---
      layout: nunu
      ---
      ## Bar
    MD

    atts, md = Syntropy::Markdown.parse_md({}, src)
    assert_equal 'nunu', atts[:layout]

    @controller = Syntropy::Markdown.make_controller(@env, atts, md)
    assert_raises(Syntropy::Error) {
      req = @test_harness.request(':method' => 'GET', ':path' => '/')
    }
  end
end
