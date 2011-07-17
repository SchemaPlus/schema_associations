# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "schema_associations/version"

Gem::Specification.new do |s|
  s.name        = "schema_associations"
  s.version     = SchemaAssociations::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Ronen Barzel", "Michał Łomnicki"]
  s.email       = ["ronen@barzel.org", "michal.lomnicki@gmail.com"]
  s.homepage    = "https://github.com/ronen/schema_associations"
  s.summary     = "Provides ActiveRecord support for foreign keys, database defined validations and associations."
  s.description = "SchemaPlus is an ActiveRecord extension that provides support for defining foreign keys and indexes in database migrations and schemas, as well as for defining model validations and associations based on the database."

  s.rubyforge_project = "schema_associations"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  s.add_dependency("schema_plus")
      
  s.add_development_dependency("rake", "~> 0.8.7")
  s.add_development_dependency("rails", ">= 3.1.0.rc1")
  s.add_development_dependency("rspec")
  s.add_development_dependency("sqlite3")
  s.add_development_dependency("simplecov")
  s.add_development_dependency("simplecov-gem-adapter")
  s.add_development_dependency("ruby-debug19") if RUBY_VERSION >= "1.9.2"
end

