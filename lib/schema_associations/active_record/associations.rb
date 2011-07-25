require 'ostruct'

module SchemaAssociations
  module ActiveRecord
    module Associations #:nodoc:

      module Relation #:nodoc:
        def self.included(base)
          base.alias_method_chain :initialize, :schema_associations
        end

        def initialize_with_schema_associations(klass, *args)
          klass.send :_load_schema_associations_associations
          initialize_without_schema_associations(klass, *args)
        end
      end

      def self.extended(base) #:nodoc:
        class << base
          alias_method_chain :reflect_on_association, :schema_associations
          alias_method_chain :reflect_on_all_associations, :schema_associations
        end
        ::ActiveRecord::Relation.send :include, Relation
      end

      def reflect_on_association_with_schema_associations(*args) #:nodoc:
        _load_schema_associations_associations
        reflect_on_association_without_schema_associations(*args)
      end

      def reflect_on_all_associations_with_schema_associations(*args) #:nodoc:
        _load_schema_associations_associations
        reflect_on_all_associations_without_schema_associations(*args)
      end

      def define_attribute_methods(*args) #:nodoc:
        super
        _load_schema_associations_associations
      end

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

      private

      def _load_schema_associations_associations #:nodoc:
        return if @schema_associations_associations_loaded
        @schema_associations_associations_loaded = true
        return unless schema_associations_config.auto_create?

        reverse_foreign_keys.each do | foreign_key |
          if foreign_key.table_name =~ /^#{table_name}_(.*)$/ || foreign_key.table_name =~ /^(.*)_#{table_name}$/
            other_table = $1
            if other_table == other_table.pluralize and connection.columns(foreign_key.table_name).any?{|col| col.name == "#{other_table.singularize}_id"}
              _define_association(:has_and_belongs_to_many, foreign_key, other_table)
            else
              _define_association(:has_one_or_many, foreign_key)
            end
          else
            _define_association(:has_one_or_many, foreign_key)
          end
        end

        foreign_keys.each do | foreign_key |
          _define_association(:belongs_to, foreign_key)
        end
      end

      def _define_association(macro, fk, referencing_table_name = nil) #:nodoc:
        return unless fk.column_names.size == 1

        referencing_table_name ||= fk.table_name
        column_name = fk.column_names.first

        references_name = fk.references_table_name.singularize
        referencing_name = referencing_table_name.singularize

        referencing_class_name = referencing_name.classify
        references_class_name = references_name.classify

        names = _determine_association_names(column_name.sub(/_id$/, ''), referencing_name, references_name)

        case macro
        when :has_and_belongs_to_many
          name = names[:has_many]
          opts = {:class_name => referencing_class_name, :join_table => fk.table_name, :foreign_key => column_name}
        when :belongs_to
          name = names[:belongs_to]
          opts = {:class_name => references_class_name, :foreign_key => column_name}
        when :has_one_or_many
          opts = {:class_name => referencing_class_name, :foreign_key => column_name}
          # use connection.indexes and connection.colums rather than class
          # methods of the referencing class because using the class
          # methods would require getting the class -- which might trigger
          # an autoload which could start some recursion making things much
          # harder to debug.
          if connection.indexes(referencing_table_name, "#{referencing_table_name} Indexes").any?{|index| index.unique && index.columns == [column_name]}
            macro = :has_one
            name = names[:has_one]
          else
            macro = :has_many
            name = names[:has_many]
            if connection.columns(referencing_table_name, "#{referencing_table_name} Columns").any?{ |col| col.name == 'position' }
              opts[:order] = :position
            end
          end
        end
        if (_filter_association(macro, name) && !_method_exists?(name))
          logger.info "[schema_associations] #{self.name || self.table_name.classify}.#{macro} #{name.inspect}, #{opts.inspect[1...-1]}"
          send macro, name, opts.dup
        end
      end

      def _determine_association_names(reference_name, referencing_name, references_name)

        references_concise = _concise_name(references_name, referencing_name)
        referencing_concise = _concise_name(referencing_name, references_name)

        if _use_concise_name?
          references = references_concise
          referencing = referencing_concise
        else
          references = references_name
          referencing = referencing_name
        end

        case reference_name
        when 'parent'
          belongs_to         = 'parent'
          has_one            = 'child'
          has_many           = 'children'

        when references_name
          belongs_to         = references
          has_one            = referencing
          has_many           = referencing.pluralize

        when /(.*)_#{references_name}$/, /(.*)_#{references_concise}$/
          label = $1
          belongs_to         = "#{label}_#{references}"
          has_one            = "#{referencing}_as_#{label}"
          has_many           = "#{referencing.pluralize}_as_#{label}"

        when /^#{references_name}_(.*)$/, /^#{references_concise}_(.*)$/
          label = $1
          belongs_to         = "#{references}_#{label}"
          has_one            = "#{referencing}_as_#{label}"
          has_many           = "#{referencing.pluralize}_as_#{label}"

        else
          belongs_to         = reference_name
          has_one            = "#{referencing}_as_#{reference_name}"
          has_many           = "#{referencing.pluralize}_as_#{reference_name}"
        end

        { :belongs_to => belongs_to.to_sym, :has_one => has_one.to_sym, :has_many => has_many.to_sym }
      end

      def _concise_name(string, other) #:nodoc:
        case
        when string =~ /^#{other}_(.*)$/           then $1
        when string =~ /(.*)_#{other}$/            then $1
        when leader = _common_leader(string,other) then string[leader.length, string.length-leader.length]
        else                                            string
        end
      end

      def _common_leader(string, other) #:nodoc:
        leader = nil
        other.split('_').each do |part|
          test = "#{leader}#{part}_"
          break unless string.start_with? test
          leader = test
        end
        return leader
      end

      def _use_concise_name? #:nodoc:
        schema_associations_config.concise_names?
      end

      def _filter_association(macro, name) #:nodoc:
        config = schema_associations_config
        return false if config.only        and not Array.wrap(config.only).include?(name)
        return false if config.except      and     Array.wrap(config.except).include?(name)
        return false if config.only_type   and not Array.wrap(config.only_type).include?(macro)
        return false if config.except_type and     Array.wrap(config.except_type).include?(macro)
        return true
      end

      def _method_exists?(name) #:nodoc:
        method_defined?(name) || private_method_defined?(name) and not (name == :type && [Object, Kernel].include?(instance_method(:type).owner))
      end

    end
  end
end
