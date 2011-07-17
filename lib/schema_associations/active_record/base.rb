module SchemaAssociations
  module ActiveRecord

    #
    # SchemaAssociations adds several methods to ActiveRecord::Base
    #
    module Base
      def self.included(base) #:nodoc:
        base.extend(ClassMethods)
        base.extend(SchemaAssociations::ActiveRecord::Associations)
      end

      module ClassMethods
        def self.extended(base) #:nodoc:
        end

        public

        # Per-model override of Config options.  Use via, e.g.
        #     class MyModel < ActiveRecord::Base
        #         schema_associations :auto_create => false
        #     end
        def schema_associations(opts)
          @schema_associations_config = SchemaAssociations.config.merge(opts)
        end

        def schema_associations_config # :nodoc:
          @schema_associations_config ||= SchemaAssociations.config.dup
        end
      end
    end
  end
end
