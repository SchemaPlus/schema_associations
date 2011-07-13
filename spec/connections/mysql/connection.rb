print "Using MySQL\n"
require 'logger'

ActiveRecord::Base.logger = Logger.new(File.open("mysql.log", "w"))

ActiveRecord::Base.configurations = {
  'schema_associations' => {
    :adapter => 'mysql',
    :database => 'schema_associations_unittest',
    :username => 'schema_assoc',
    :encoding => 'utf8',
    :socket => '/tmp/mysql.sock',
    :min_messages => 'warning'
  }

}

ActiveRecord::Base.establish_connection 'schema_associations'
