print "Using SQLite3\n"
require 'logger'

ActiveRecord::Base.logger = Logger.new(File.open("sqlite3.log", "w"))

ActiveRecord::Base.configurations = {
  'schema_associations' => {
    :adapter => 'sqlite3',
    :database => File.expand_path('schema_associations.sqlite3', File.dirname(__FILE__)),
  }

}

ActiveRecord::Base.establish_connection 'schema_associations'
