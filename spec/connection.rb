
ActiveRecord::Base.configurations = {
  'schema_associations' => {
    :adapter => 'sqlite3',
    :database => File.expand_path('schema_associations.sqlite3', File.dirname(__FILE__)),
  }

}

ActiveRecord::Base.establish_connection 'schema_associations'
ActiveRecord::Base.connection.execute "PRAGMA synchronous = OFF"
