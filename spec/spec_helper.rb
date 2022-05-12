# frozen_string_literal: true

require 'simplecov'
SimpleCov.start unless SimpleCov.running

$LOAD_PATH.unshift(File.dirname(__FILE__))
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))

require 'rspec'
require 'active_record'
require 'schema_associations'
require 'logger'
require 'schema_dev/rspec'

SchemaDev::Rspec::setup

Dir[File.dirname(__FILE__) + "/support/**/*.rb"].each { |f| require f }

SimpleCov.command_name "[Ruby #{RUBY_VERSION} - ActiveRecord #{::ActiveRecord::VERSION::STRING}]"
