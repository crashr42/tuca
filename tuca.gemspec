require File.expand_path('../lib/tuca/version', __FILE__)

Gem::Specification.new do |gem|
  gem.authors       = %w(nikita)
  gem.email         = %w(nikita.kem@gmail.com)
  gem.description   = %q{EventMachine based transmission client}
  gem.summary       = %q{Transmission client}
  gem.homepage      = 'https://github.com/crashr42/tuca'

  gem.files         = `git ls-files`.split($\)
  gem.autorequire   = %q{tuca}
  gem.test_files    = gem.files.grep(%r{^(test|spec|features|examples)/})
  gem.name          = 'tuca'
  gem.require_paths = %w(lib)
  gem.version       = Tuca::VERSION
  gem.add_dependency('json', '>= 1.7.5')
  gem.add_dependency('em-http-request', '>= 1.0.2')
end
