GitRepository = import '_lib/git_repository'

repos = {}
@env[:config][:repositories].each do |d|
  path = File.expand_path(d[:path])
  repo = GitRepository.new(path, d[:description])
  repos[d[:name]] = repo
end

export repos
