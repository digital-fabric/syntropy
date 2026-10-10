require 'syntropy/mime_types'

class GitRepository
  attr_reader :path, :name, :description, :commits
  
  def initialize(path, description)
    @path = path
    @rel_re = /^#{path}\//.freeze
    @files = {}
    @description = description
    setup
  end

  def get(rel_path)
    item = @files[rel_path]
    return nil if !item
    
    item[:mime_type] ||= Syntropy::MimeTypes[
      (m = item[:ref].match(/([^\.]+)$/)) && m[1]
    ]
    item[:binary] = binary_file?(item[:fn]) if item[:binary].nil?
    
    item
  end

  def list
    @files.values
  end

  private

  def setup
    @name = File.basename(@path)

    fn = File.join(@path, '.git/description')
    @description ||= File.exist?(fn) ? File.read(fn).strip : ""

    r = `git -C #{@path} ls-tree -r --name-only HEAD`
    files = r.lines.map(&:chomp).map { File.join(@path, it) }. select { File.file?(it) }
    calc_tree(files)

    @commits = get_commits
  end

  def calc_tree(files)
    @readme_fn = files.find { |file_path| file_path =~ /\AREADME(\.md)?\z/ }
    files.each do |fn|
      ref = rel_path(fn)
      item = { fn:, ref: }
      @files[ref] = item
    end
  end

  def rel_path(path)
    path.gsub(@rel_re, '')
  end

  def binary_file?(fn)
    File.binread(fn, 8000).to_s.include?("\0")
  end

  def get_commits
    `git log --date=short --pretty=format:'%h  %ad  %an  %s'`.lines
  end
end

export GitRepository
