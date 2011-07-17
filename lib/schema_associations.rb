require 'schema_plus'
require 'valuable'

require 'schema_associations/version'
require 'schema_associations/active_record/base'
require 'schema_associations/active_record/associations'
require 'schema_associations/railtie' if defined?(Rails)

module SchemaAssociations

  # This global configuation options for SchemaAssociations
  # Set them in +config/initializers/schema_associations.rb+ using:
  #
  #    SchemaAssociations.setup do |config|
  #       ...
  #    end
  #
  #
  class Config < Valuable

    ##
    # :attr_accessor: auto_create
    #
    # Whether to automatically create associations based on foreign keys.
    # Boolean, default is +true+.
    has_value :auto_create, :klass => :boolean, :default => true

    ##
    # :attr_accessor: concise_names
    #
    # Whether to use concise naming (strip out common prefixes from class names).
    # Boolean, default is +true+.
    has_value :concise_names, :klass => :boolean, :default => true

    ##
    # :attr_accessor: except
    #
    # List of association names to exclude from automatic creation.
    # Value is a single name, an array of names, or +nil+.  Default is +nil+.
    has_value :except, :default => nil

    ##
    # :attr_accessor: only
    #
    # List of association names to include in automatic creation.
    # Value is a single name, and array of names, or +nil+.  Default is +nil+.
    has_value :only, :default => nil

    ##
    # :attr_accessor: except_type
    #
    # List of association types to exclude from automatic creation.
    # Value is one or an array of +:belongs_to+, +:has_many+, +:has_one+, and/or
    # +:has_and_belongs_to_many+, or +nil+.  Default is +nil+.
    has_value :except_type, :default => nil

    ##
    # :attr_accessor: only_type
    #
    # List of association types to include from automatic creation.
    # Value is one or an array of +:belongs_to+, +:has_many+, +:has_one+, and/or
    # +:has_and_belongs_to_many+, or +nil+.  Default is +nil+.
    has_value :only_type, :default => nil

    def dup #:nodoc:
      self.class.new(Hash[attributes.collect{ |key, val| [key, Valuable === val ?  val.class.new(val.attributes) : val] }])
    end

    def update_attributes(opts)#:nodoc:
      opts = opts.dup
      opts.keys.each { |key| self.send(key).update_attributes(opts.delete(key)) if self.class.attributes.include? key and Hash === opts[key] }
      super(opts)
      self
    end

    def merge(opts)#:nodoc:
      dup.update_attributes(opts)
    end

  end

  # Returns the global configuration, i.e., the singleton instance of Config
  def self.config
    @config ||= Config.new
  end

  # Initialization block is passed a global Config instance that can be
  # used to configure SchemaAssociations behavior.  E.g., if you want to disable
  # automation creation of foreign key constraints for columns name *_id,
  # put the following in config/initializers/schema_associations.rb :
  #
  #    SchemaAssociations.setup do |config|
  #       config.auto_create = false
  #    end
  #
  def self.setup # :yields: config
    yield config
  end

  def self.insert #:nodoc:
    return if @inserted
    @inserted = true
    ::ActiveRecord::Base.send(:include, SchemaAssociations::ActiveRecord::Base)
  end

end

SchemaAssociations.insert unless defined? Rails::Railtie
