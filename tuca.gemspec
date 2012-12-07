require File.expand_path('../lib/tuca/version', __FILE__)

Gem::Specification.new do |gem|
  gem.authors       = %w(nikita)
  gem.email         = %w(nikita.kem@gmail.com)
  gem.description   = %q{EventMachine based transmission client}
  gem.summary       = %q{Transmission client}
  gem.homepage      = "https://github.com/crashr42/tuca"

  gem.files         = `git ls-files`.split($\)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.name          = "tuca"
  gem.require_paths = %w(lib)
  gem.version       = Tuca::VERSION
end
