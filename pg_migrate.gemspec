# -*- encoding: utf-8 -*-
require File.expand_path('../lib/pg_migrate/version', __FILE__)

Gem::Specification.new do |gem|
  gem.authors       = ["Seth Call"]
  gem.email         = ["sethcall@gmail.com"]
  gem.description   = %q{Migrate postgres database}
  gem.summary       = %q{Migrate postgres database}
  gem.homepage      = ""

  gem.files         = `git ls-files`.split($\)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.name          = "pg_migrate"
  gem.require_paths = ["lib"]
  gem.version       = PgMigrate::VERSION

  gem.add_dependency('logging', '1.7.2')
  
  #gem.add_development_dependency('files')
  gem.add_dependency('pg', '0.14.0')
end
