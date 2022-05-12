# frozen_string_literal: true

$:.push File.expand_path("../lib", __FILE__)
require "schema_associations/version"

Gem::Specification.new do |gem|
  gem.name        = "schema_associations"
  gem.version     = SchemaAssociations::VERSION
  gem.platform    = Gem::Platform::RUBY
  gem.authors     = ["Ronen Barzel", "Michał Łomnicki"]
  gem.email       = ["ronen@barzel.org", "michal.lomnicki@gmail.com"]
  gem.homepage    = "https://github.com/SchemaPlus/schema_associations"
  gem.summary     = "ActiveRecord extension that automatically (DRY) creates associations based on the schema"
  gem.description = "SchemaAssociations extends ActiveRecord to automatically create associations by inspecting the database schema.  This is more more DRY than the standard behavior, for which in addition to specifying the foreign key in the migration, you must also specify complementary associations in two model files (e.g. a :belongs_to and a :has_many)."

  gem.files         = `git ls-files`.split("\n")
  gem.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  gem.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  gem.require_paths = ["lib"]

  gem.required_ruby_version = '>= 2.5'

  gem.add_dependency 'activerecord', '>= 5.2', '< 7.1'
  gem.add_dependency 'schema_plus_foreign_keys', '~> 1.1.0'
  gem.add_dependency 'valuable'

  gem.add_development_dependency 'bundler'
  gem.add_development_dependency 'rake', '~> 13.0'
  gem.add_development_dependency 'rspec', '~> 3.0'
  gem.add_development_dependency 'schema_dev', '~> 4.2.0'
end
