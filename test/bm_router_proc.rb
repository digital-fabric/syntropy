# frozen_string_literal: true

require 'bundler/inline'

gemfile do
  gem 'syntropy', path: '.'
  gem 'roda'
  gem 'benchmark-ips'
end

require 'syntropy'
require 'roda'
require 'benchmark/ips'
require 'securerandom'
require 'rack/mock_request'
require 'qeweney/mock_adapter'

class BM
  def self.name(name)
    define_method(:name) { name }
  end

  def self.run(&block)
    new(&block).run
  end

  def initialize(&block)
    @entry_classes = []
    instance_exec(&block)
  end

  def entry(name, &block)
    k = Class.new(Entry)
    k.define_method(:name) { name }
    k.class_exec(&block)
    @entry_classes << k
  end

  def run
    entries = @entry_classes.map { it.new.tap(&:setup) }

    Benchmark.ips do |x|
      entries.each do |e|
        x.report(e.name) { e.call }
      end
      x.compare!(order: :baseline)
    end
  end

  class Entry
    def setup
    end

    def call
      raise NotImplementedError
    end
  end
end

################################################################################

class RodaRouter < Roda
  route do |r|
    # GET / request
    r.root do

      r.redirect "/hello"
    end

    # /hello branch
    r.on "hello" do
      # Set variable for all routes in /hello branch
      @greeting = 'Hello'

      # GET /hello/world request
      r.get "world" do
        "#{@greeting} world!"
      end

      # /hello request
      r.is do
        # GET /hello request
        r.get do
          "#{@greeting}!"
        end

        # POST /hello request
        r.post do
          puts "Someone said #{@greeting}!"
          r.redirect
        end
      end
    end
  end
end

req = Rack::MockRequest.env_for("http://example.com:8080/hello/world")
roda_app = RodaRouter.app
p roda_app.(req)

################################################################################

class Qeweney::Request
  def response_headers
    adapter.headers
  end

  def response_status
    adapter.status
  end

  def response_body
    adapter.body
  end

  def response_json
    raise if response_content_type != 'application/json'
    JSON.parse(response_body, symbolize_names: true)
  end

  def response_content_type
    response_headers['Content-Type']
  end
end

def make_tmp_file_tree(dir, spec)
  FileUtils.mkdir(dir) rescue nil
  spec.each do |k, v|
    fn = File.join(dir, k.to_s)
    case v
    when String
      IO.write(fn, v)
    when Hash
      FileUtils.mkdir(fn) rescue nil
      make_tmp_file_tree(fn, v)
    end
  end
  dir
end

ROOT_DIR = "/tmp/#{__FILE__.gsub('/', '-')}-#{SecureRandom.hex}"
make_tmp_file_tree(ROOT_DIR, {
  'index.rb': "export ->(req) { req.redirect('/hello') }",
  'hello': {
    'index.rb': "export ->(req) { req.respond('Hello!', 'Content-Type' => 'text/html') }",
    'world.rb': "export ->(req) { req.respond('Hello world!', 'Content-Type' => 'text/html') }",
  }
})

machine = UM.new
syntropy_app = Syntropy::App.new(
  root_dir: ROOT_DIR,
  mount_path: '/',
  machine: machine
)
proc = ->(req) { syntropy_app.(req) }

module ::Kernel
  def mock_req(headers, body = nil)
    Qeweney::MockAdapter.mock(headers, body).tap { it.setup_mock_request }
  end
end

puts '*' * 40

req = mock_req(':method' => 'GET', ':path' => '/hello/world')
proc.(req)
p [req.response_status, req.response_headers, req.response_body]

################################################################################

BM.run do
  entry(:roda) {
    def setup
      @app = RodaRouter.app
    end
    
    def call
      req = Rack::MockRequest.env_for("http://example.com:8080/hello/world")
      @app.(req)
    end
  }

  entry(:syntropy) {
    def setup
      machine = UM.new
      syntropy_app = Syntropy::App.new(
        root_dir: ROOT_DIR,
        mount_path: '/',
        # watch_files: 0.05,
        machine: machine
      )
      @app = ->(req) { syntropy_app.(req) }
    end

    def call
      req = mock_req(':method' => 'GET', ':path' => '/hello/world')
      @app.(req)
    end
  }
end
