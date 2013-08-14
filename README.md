# SchemaAssociations

SchemaAssociations is an ActiveRecord extension that keeps your model class
definitions simpler and more DRY, by automatically defining associations based
on the database schema.

[![Gem Version](https://badge.fury.io/rb/schema_associations.png)](http://badge.fury.io/rb/schema_associations)
[![Build Status](https://secure.travis-ci.org/lomba/schema_associations.png)](http://travis-ci.org/lomba/schema_associations)
[![Dependency Status](https://gemnasium.com/lomba/schema_associations.png)](https://gemnasium.com/lomba/schema_associations)

## Overview

One of the great things about Rails (ActiveRecord, in particular) is that it
inspects the database and automatically defines accessors for all your
columns, keeping your model class definitions simple and DRY.  That's great
for simple data columns, but where it falls down is when your table contains
references to other tables: then the "accessors" you need are the associations
defined using `belongs_to`, `has_one`, `has_many`, and
`has_and_belongs_to_many` -- and you need to put them into your model class
definitions by hand.  In fact, for every relation, you need to define two
associations each listing its inverse, such as

    class Post < ActiveRecord::Base
        has_many :comments, :inverse_of => :post
    end

    class Comment < ActiveReocrd::Base
        belongs_to :post, :inverse_of => :comments
    end

....which isn't so DRY.

Enter the SchemaAssociations gem.  It extends ActiveRecord to automatically
define the appropriate associations based on foreign key constraints in the
database.  SchemaAssociations builds on the
[schema_plus](http://rubygems.org/gems/schema_plus) gem that automatically
defines foreign key constraints.  So the common case is simple -- if you have
this in your migration:

    create_table :posts do |t|
    end

    create_table :comments do |t|
      t.integer post_id
    end

Then all you need for your models is:

    class Post < ActiveRecord::Base
    end

    class Comment < ActiveRecord::Base
    end

and SchemaAssociations defines the appropriate associations under the hood.

### What if I want something special?

You're always free to define associations yourself, if for example you want to
pass special options.  SchemaAssociations won't clobber any existing
definitions.

You can also control the behavior with various options, globally via
SchemaAssociations::setup or per-model via
SchemaAssociations::ActiveRecord#schema_associations, such as:

    class Post < ActiveRecord::Base
        schema_associations :concise_names => false
    end

See the [SchemaAssociations::Confg RDOC](http://rubydoc.info/gems/schema_associations/SchemaAssociations/Config) for the available options.

### This seems cool, but I'm worried about too much automagic

You can globally turn off automatic creation in
`config/initializers/schema_associations.rb`:

    SchemaAssociations.setup do |config|
      config.auto_create = false
    end

Then in any model where you want automatic associations, just do

    class Post < ActiveRecord::Base
      schema_associations
    end

You can also pass options as per above.

## Full Details

### The basics

The common cases work entirely as you'd expect.  For a one-to-many
relationship using standard naming conventions:

    # migration:

    create_table :comments do |t|
        t.integer post_id
    end

    # schema_associations defines:

    class Post < ActiveRecord::Base
        has_many :comments
    end

    class Comment < ActiveReocrd::Base
        belongs_to :post
    end

For a one-to-one relationship:

    # migration:

    create_table :comments do |t|
        t.integer post_id, :index => :unique    # (using the :index option provided by schema_plus )
    end

    # schema_associations defines:

    class Post < ActiveRecord::Base
        has_one :comment
    end

    class Comment < ActiveReocrd::Base
        belongs_to :post
    end

And for many-to-many relationships:

    # migration:

    create_table :groups_members do |t|
        integer :group_id
        integer :member_id
    end

    # schema_associations defines:

    class Group < ActiveReocrd::Base
        has_and_belongs_to_many :members
    end

    class Member < ActiveRecord::Base
        has_and_belongs_to_many :groups
    end

### Unusual names, multiple references

Sometimes you want or need to deviate from the simple naming conventions.  In
this case, the `belongs_to` relationship name is taken from the name of the
foreign key column, and the `has_many` or `has_one` is named by the
referencing table, suffixed with "as" the relationship name.  An example
should make this clear...

Suppose your company hires interns, and each intern is assigned a manager and
a mentor, who are regular employees. 

    create_table :interns do |t|
        t.integer :manager_id,      :references => :employees
        t.integer :mentor_id,       :references => :employees
    end

SchemaAssociations defines a `belongs_to` association for each reference,
named according to the column:

    class Intern < ActiveRecord::Base
        belongs_to  :manager, :class_name => "Employee", :foreign_key => "manager_id"
        belongs_to  :mentor,  :class_name => "Employee", :foreign_key => "mentor_id"
    end

And the corresponding `has_many` association each gets a suffix to indicate
which one relation it refers to:

    class Employee < ActiveRecord::Base
        has_many :interns_as_manager, :class_name => "Intern", :foreign_key => "manager_id"
        has_many :interns_as_mentor,  :class_name => "Intern", :foreign_key => "mentor_id"
    end

### Special case for trees

If your forward relation is named "parent", SchemaAssociations names the
reverse relation "child" or "children".  That is, if you have:

    create_table :nodes
       t.integer :parent_id         # schema_plus assumes it's a reference to this table
    end

Then SchemaAssociations will define

    class Node < ActiveRecord::Base
        belongs_to :parent, :class_name => "Node", :foreign_key => "parent_id"
        has_many :children, :class_name => "Node", :foreign_key => "parent_id"
    end

### Concise names

For modularity in your tables and classes, you might  use a common prefix for
related objects.  For example, you may have widgets each of which has a color,
and might have one base that has a top color and a bottom color, from the same
set of colors.

    create_table :widget_colors |t|
    end

    create_table :widgets do |t|
        t.integer   :widget_color_id
    end

    create_table :widget_base
        t.integer :widget_id, :index => :unique
        t.integer :top_widget_color_id,    :references => :widget_colors
        t.integer :bottom_widget_color_id, :references => :widget_colors
    end

Using the full name for the associations would make your code verbose and not
quite DRY:

    @widget.widget_color
    @widget.widget_base.top_widget_color

Instead, by default, SchemaAssociations uses concise names: shared leading
words are removed from the association name.  So instead of the above, your
code looks like:

    @widget.color
    @widget.base.top_color

i.e. these associations would be defined:

    class WidgetColor < ActiveRecord::Base
        has_many :widgets,         :class_name => "Widget",     :foreign_key => "widget_color_id"
        has_many :bases_as_top,    :class_name => "WidgetBase", :foreign_key => "top_widget_color_id"
        has_many :bases_as_bottom, :class_name => "WidgetBase", :foreign_key => "bottom_widget_color_id"
    end

    class Widget < ActiveRecord::Base
        belongs_to :color, :class_name => "WidgetColor", :foreign_key => "widget_color_id"
        has_one    :base,  :class_name => "WidgetBase",  :foreign_key => "widget_base_id"
    end

    class WidgetBase < ActiveRecord::Base
        belongs_to :top_color,    :class_name => "WidgetColor", :foreign_key => "top_widget_color_id"
        belongs_to :bottom_color, :class_name => "WidgetColor", :foreign_key => "bottom_widget_color_id"
        belongs_to :widget,       :class_name => "Widget",      :foreign_key => "widget_id"
    end

If you like the formality of using full names for the asociations, you can
turn off concise names globally or per-model, see [SchemaAssociations::Config](http://rubydoc.info/gems/schema_associations/SchemaAssociations/Config)

### Ordering `has_many` using `position`

If the target of a `has_many` association has a column named `position`,
SchemaAssociations will specify `:order => :position` for the association. 
That is,

    create_table :comments do |t|
        t.integer post_id
        t.integer position
    end

leads to

    class Post < ActiveRecord::Base
      has_many :comments, :order => :position
    end
    
## Table names and model class names

SchemaAssociations determins the mode class name from the table name using the same convention (and helpers) that ActiveRecord uses.  But sometimes you might be doing things differently.  For example, in an engine you might have a prefix that goes in front of all table names, and the models might all be in a namespace.  

To that end, SchemaAssociations lets you configure mappings from a table name prefix to a model class name prefix to use instead.  For example, suppose your database had tables:
      
      hpy_campers
      hpy_go_lucky

The default model class names would be

	  HpyCampers
	  HpyGoLucky
	 
But if instead you wanted

	  Happy::Campers
	  Happy::GoLucky
	  
You could set up this mapping in `config/initializers/schema_associations.rb`:

      SchemaPlus.setup do |config|
          config.table_prefix_map["hpy_"] = "Happy::"
      end

Tables names that don't start with `hpy_` will continue to use the default determination.

You can set up multiple mappings.  E.g. if you're using several engines they can each set up the mapping for their own moduels.  

You can set up a mapping from or to the empty string, in order to unconditionally add or remove prefixes from all model class names.


## How do I know what it did?

If you're curious (or dubious) about what associations SchemaAssociations
defines, you can check the log file.  For every assocation that
SchemaAssociations defines, it generates an info entry such as

    [schema_associations] Post.has_many :comments, :class_name "Comment", :foreign_key "comment_id"

which shows the exact method definition call.


SchemaAssociations defines the associations lazily, only creating them when
they're first needed.  So you may need to search through the log file to find
them all (and some may not be defined at all if they were never needed for the
use cases that you logged).

## Compatibility

SchemaAssociations supports all combinations of:

*   Rails 3.2 or rails 4.0
*   MRI ruby 1.9.3 or 2.0.0

Note: As of version 1.0.0, ruby 1.8.7 and rails < 3.2 are no longer supported.  As of version 1.2.0, ruby 1.9.2 is no longer supported.

## Installation

Install from http://rubygems.org via

    $ gem install "schema_associations"

or in a Gemfile

    gem "schema_associations"

## Testing

SchemaAssociations is tested using rspec, sqlite3, and rvm, with some hackery
to test against multiple versions of rails and ruby.  To run the full combo of
tests, after you've forked & cloned: 

    $ cd schema_associations
    $ ./runspecs --install  # do this once to install gem dependencies for all versions (slow)
    $ ./runspecs # as many times as you like

See `./runspecs --help` for more options.  In particular, to run rspec on a
specific file or example (rather than running the full suite) you can do, e.g.

    $ ./runspecs [other options] --rspec -- spec/association_spec.rb -e 'base'

Code coverage results will be in coverage/index.html -- it should be at 100% coverage.

## Release notes:

### 1.2.0

* Works with Rails 4, thanks to [@tovodeverett](https://github.com/tovodeverett)
* Test against MRI ruby 2.0.0; no longer test against 1.9.2

### 1.1.0

* New feature: `config.table_prefix_map`

### 1.0.1

*   Bug fix: use singular :inverse_of for :belongs_to of a :has_one 


### 1.0.0

*   Use :inverse_of in generated associations

*   Drop support for ruby 1.8.7 and rails < 3.2


## History

*   SchemaAssociations is derived from the "Red Hill On Rails" plugin
    foreign_key_associations originally created by harukizaemon
    (https://github.com/harukizaemon)

*   SchemaAssociations was created in 2011 by Michal Lomnicki and Ronen Barzel


## License

This gem is released under the MIT license.
