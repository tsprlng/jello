Gem::Specification.new do |s|
  s.name = 'tsprlng-jello'
  s.version = '1.0.0wip'
  s.summary = "Trellira"
  s.authors = ["tsprlng"]
  # s.require_paths = ["lib"]

  # Files
  s.files = `git ls-files`.split($\)
  s.test_files = s.files.grep(%r{^(test|spec|features)/})

  # Gem dependencies
  s.add_runtime_dependency 'faraday'
end
