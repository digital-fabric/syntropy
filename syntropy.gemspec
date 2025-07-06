require_relative './lib/syntropy/version'

Gem::Specification.new do |s|
  s.name        = 'syntropy'
  s.summary     = 'Syntropic Web Framework'
  s.version       = Syntropy::VERSION
  s.licenses      = ['MIT']
  s.author        = 'Sharon Rosner'
  s.email         = 'sharon@noteflakes.com'
  s.files         = `git ls-files`.split

  s.homepage      = 'https://github.com/noteflakes/syntropy'
  s.metadata      = {
    'homepage_uri' => 'https://github.com/noteflakes/syntropy',
    'documentation_uri' => 'https://www.rubydoc.info/gems/syntropy',
    'changelog_uri' => 'https://github.com/noteflakes/syntropy/blob/master/CHANGELOG.md'
  }
  s.rdoc_options  = ['--title', 'Extralite', '--main', 'README.md']
  s.extra_rdoc_files = ['README.md']
  s.require_paths = ['lib']
  s.required_ruby_version = '>= 3.4'
  s.executables = ['syntropy']

  s.add_dependency 'extralite',     '2.12'
  s.add_dependency 'json',          '2.12.2'
  s.add_dependency 'papercraft',    '1.4'
  s.add_dependency 'qeweney',       '0.21'
  s.add_dependency 'tp2',           '0.13.4'
  s.add_dependency 'uringmachine',  '0.16'

  s.add_dependency 'listen',        '3.9.0'
  s.add_dependency 'logger',        '1.7.0'

  s.add_development_dependency 'minitest',  '5.25.5'
  s.add_development_dependency 'rake',      '13.3.0'

end
