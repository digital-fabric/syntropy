# frozen_string_literal: true

module Syntropy
  class Router
    attr_reader :cache

    def initialize(opts, module_loader = nil)
      raise 'Invalid location given' if !File.directory?(opts[:location])

      @opts = opts
      @machine = opts[:machine]
      @root = File.expand_path(opts[:location])
      @mount_path = opts[:mount_path] || '/'
      @rel_path_re ||= /^#{@root}/
      @module_loader = module_loader

      @cache        = {} # maps url path to route entry
      @routes       = {} # maps canonical path to route entry (actual routes)
      @files        = {} # maps filename to entry
      @deps         = {} # maps filenames to array of dependent entries
      @x  = {} # maps directories to hook chains

      scan_routes
    end

    def [](path)
      get_route_entry(path)
    end

    def start_file_watcher
      @opts[:logger]&.call('Watching for file changes...', nil)
      @machine.spin { file_watcher_loop }
    end

    private

    HIDDEN_RE = /^_/

    def scan_routes(dir = nil)
      dir ||= @root

      Dir[File.join(dir, '*')].each do
        basename = File.basename(it)
        next if (basename =~ HIDDEN_RE)

        File.directory?(it) ? scan_routes(it) : add_route(it)
      end
    end

    def add_route(fn)
      kind = route_kind(fn)
      rel_path = path_rel(fn)
      canonical_path = path_canonical(rel_path, kind)
      entry = { kind:, fn:, canonical_path: }
      entry[:handle_subtree] = true if (kind == :module) && !!(fn =~ /\+\.rb$/)

      @routes[canonical_path] = entry
      @files[fn] = entry
    end

    def route_kind(fn)
      case File.extname(fn)
      when '.md'
        :markdown
      when '.rb'
        :module
      else
        :static
      end
    end

    def path_rel(path)
      path.gsub(@rel_path_re, '')
    end

    def path_abs(path, base)
      File.join(base, path)
    end

    PATH_PARENT_RE = /^(.+)?\/([^\/]+)$/

    def path_parent(path)
      return nil if path == '/'

      path.match(PATH_PARENT_RE)[1] || '/'
    end

    MD_EXT_RE = /\.md$/
    RB_EXT_RE = /[+]?\.rb$/
    INDEX_RE = /^(.*)\/index[+]?\.(?:rb|md|html)$/

    def path_canonical(rel_path, kind)
      clean = path_clean(rel_path, kind)
      clean.empty? ? @mount_path : File.join(@mount_path, clean)
    end

    def path_clean(rel_path, kind)
      if (m = rel_path.match(INDEX_RE))
        return m[1]
      end

      case kind
      when :static
        rel_path
      when :markdown
        rel_path.gsub(MD_EXT_RE, '')
      when :module
        rel_path.gsub(RB_EXT_RE, '')
      end
    end

    def get_route_entry(path, use_cache: true)
      if use_cache
        cached = @cache[path]
        return cached if cached
      end

      entry = find_route_entry(path)
      set_cache(path, entry) if use_cache && entry[:kind] != :not_found
      entry
    end

    def set_cache(path, entry)
      @cache[path] = entry
      (entry[:cache_keys] ||= {})[path] = true
    end

    # We don't allow access to path with /.., or entries that start with _
    FORBIDDEN_RE = %r{(/_)|((/\.\.)/?)}
    NOT_FOUND = { kind: :not_found }.freeze

    def find_route_entry(path)
      return NOT_FOUND if path =~ FORBIDDEN_RE

      @routes[path] || find_index_route(path) || find_up_tree_module(path) || NOT_FOUND
    end

    INDEX_OPT_EXT_RE = /^(.*)\/index(?:\.(?:rb|md|html))?$/

    def find_index_route(path)
      m = path.match(INDEX_OPT_EXT_RE)
      return nil if !m

      @routes[m[1]]
    end

    def find_up_tree_module(path)
      parent_path = path_parent(path)
      return nil if !parent_path

      entry = @routes[parent_path]
      return entry if entry && entry[:handle_subtree]

      find_up_tree_module(parent_path)
    end

    def file_watcher_loop
      wf = @opts[:watch_files]
      period = wf.is_a?(Numeric) ? wf : 0.1
      Syntropy.file_watch(@machine, @root, period: period) do |event, fn|
        handle_changed_file(event, fn)
      rescue Exception => e
        p e
        p e.backtrace
        exit!
      end
    end

    def handle_changed_file(event, fn)
      @opts[:logger]&.call("Detected changed file: #{event} #{fn}")
      @module_loader&.invalidate(fn)
      case event
      when :added
        handle_added_file(fn)
      when :removed
        handle_removed_file(fn)
      when :modified
        handle_modified_file(fn)
      end
    end

    def handle_added_file(fn)
      add_route(fn)
      @cache.clear # TODO: remove only relevant cache entries
    end

    def handle_removed_file(fn)
      entry = @files[fn]
      if entry
        remove_entry_cache_keys(entry)
        @routes.delete(entry[:canonical_path])
        @files.delete(fn)
      end
    end

    def handle_modified_file(fn)
      entry = @files[fn]
      if entry && entry[:kind] == :module
        # invalidate the entry proc, so it will be recalculated
        entry[:proc] = nil
      end
    end

    def remove_entry_cache_keys(entry)
      entry[:cache_keys]&.each_key { @cache.delete(it) }.clear
    end
  end
end
