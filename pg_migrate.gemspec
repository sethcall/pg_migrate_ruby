# -*- encoding: utf-8 -*-
require File.expand_path('../lib/pg_migrate/version', __FILE__)
lib=File.expand_path('../lib', __FILE__)

Gem::Specification.new do |gem|
  gem.authors       = ["Seth Call"]
  gem.email         = ["sethcall@gmail.com"]
  gem.description   = %q{Simple migration tool focused on Postgresql}
  gem.summary       = %q{Create migration scripts in raw SQL that work regardless if they are run from the pg_migrate command-line, psql, or native code integration.  More documentation exists on the project homepage.)}
  gem.homepage      = "https://github.com/sethcall/pg_migrate"

  gem.files         = `git ls-files`.split($\)
  gem.files        += ['lib/pg_migrate/templates/bootstrap.erb']
  gem.files	   += ['lib/pg_migrate/templates/up.erb']
  gem.files.delete("lib/pg_migrate/templates")
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.name          = "pg_migrate"
  gem.require_paths = ["lib"]
  gem.version       = PgMigrate::VERSION

  gem.add_dependency('logging', '1.7.2')
  
  gem.add_dependency('pg', '0.17.1')
  gem.add_dependency('thor', '0.15.4')
  #gem.add_dependency('rubygems', '1.8.24')

end

