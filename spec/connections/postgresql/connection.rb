print "Using PostgreSQL\n"
require 'logger'

ActiveRecord::Base.logger = Logger.new(File.open("postgresql.log", "w"))

ActiveRecord::Base.configurations = {
  'schema_associations' => {
    :adapter => 'postgresql',
    :database => 'schema_associations_unittest',
    :min_messages => 'warning'
  }

}

ActiveRecord::Base.establish_connection 'schema_associations'
