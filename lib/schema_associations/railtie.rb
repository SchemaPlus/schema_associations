module SchemaAssociations
  class Railtie < Rails::Railtie #:nodoc:

    initializer 'schema_associations.insert', :after => :load_config_initializers do
      SchemaAssociations.insert
    end

  end
end
