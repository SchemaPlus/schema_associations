require 'bundler'
Bundler::GemHelper.install_tasks

require 'schema_dev/tasks'

task :default => :spec

require 'rspec/core/rake_task'
RSpec::Core::RakeTask.new(:spec)
