# SchemaAssociations

SchemaAssociations is an ActiveRecord extension that keeps your model class
definitions simpler and more DRY, by automatically defining associations based
on the database schema.

[![Gem Version](https://badge.fury.io/rb/schema_associations.svg)](http://badge.fury.io/rb/schema_associations)
[![Build Status](https://secure.travis-ci.org/SchemaPlus/schema_associations.svg)](http://travis-ci.org/SchemaPlus/schema_associations)
[![Coverage Status](https://img.shields.io/coveralls/SchemaPlus/schema_associations.svg)](https://coveralls.io/r/SchemaPlus/schema_associations?branch=master)


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

```ruby
class Post < ActiveRecord::Base
    has_many :comments, inverse_of: :post
end

class Comment < ActiveRecord::Base
    belongs_to :post, inverse_of: :comments
end
```

....which isn't so DRY.

Enter the SchemaAssociations gem.  It extends ActiveRecord to automatically define the appropriate associations based on foreign key constraints in the database.  

SchemaAssociations works particularly well with the
[schema_auto_foreign_keys](http://github.com/SchemaPlus/schema_auto_foreign_keys) gem which automatically
defines foreign key constraints.  So the common case is simple -- if you have this in your migration:

```ruby
create_table :posts do |t|
end

create_table :comments do |t|
    t.integer post_id
end
```

Then all you need for your models is:

```ruby
class Post < ActiveRecord::Base
end

class Comment < ActiveRecord::Base
end
```

and SchemaAssociations defines the appropriate associations under the hood.

### What if I want something special?

You're always free to define associations yourself, if for example you want to
pass special options.  SchemaAssociations won't clobber any existing
definitions. 

You can also control the behavior with various options, via a global initializer and/or per-model.  See the [Configuration section](#configuration) for the available options.

### This seems cool, but I'm worried about too much automagic

You can globally turn off automatic creation in
`config/initializers/schema_associations.rb`:

```ruby
SchemaAssociations.setup do |config|
    config.auto_create = false
end
```

Then in any model where you want automatic associations, just do

```ruby
class Post < ActiveRecord::Base
    schema_associations
end
```

You can also pass options as described in [Configuration](#configuration)

## Full Details

### The basics

The common cases work entirely as you'd expect.  For a one-to-many
relationship using standard naming conventions:

```ruby
#
# migration:
#
create_table :comments do |t|
    t.integer post_id
end

#
# schema_associations defines:
#
class Post < ActiveRecord::Base
    has_many :comments
end

class Comment < ActiveReocrd::Base
    belongs_to :post
end
```

For a one-to-one relationship:

```ruby
#
# migration:
#
create_table :comments do |t|
    t.integer post_id, index: :unique    # (using the :index option provided by schema_plus )
end

#
# schema_associations defines:
#
class Post < ActiveRecord::Base
    has_one :comment
end

class Comment < ActiveReocrd::Base
    belongs_to :post
end
```

And for many-to-many relationships:

```ruby
#
# migration:
#
create_table :groups_members do |t|
    integer :group_id
    integer :member_id
end

#
# schema_associations defines:
#
class Group < ActiveReocrd::Base
    has_and_belongs_to_many :members
end

class Member < ActiveRecord::Base
    has_and_belongs_to_many :groups
end
```

### Unusual names, multiple references

Sometimes you want or need to deviate from the simple naming conventions.  In
this case, the `belongs_to` relationship name is taken from the name of the
foreign key column, and the `has_many` or `has_one` is named by the
referencing table, suffixed with "as" the relationship name.  An example
should make this clear...

Suppose your company hires interns, and each intern is assigned a manager and
a mentor, who are regular employees.

```ruby
create_table :interns do |t|
    t.integer :manager_id,      references: :employees
    t.integer :mentor_id,       references: :employees
end
```

SchemaAssociations defines a `belongs_to` association for each reference,
named according to the column:

```ruby
class Intern < ActiveRecord::Base
    belongs_to  :manager, class_name: "Employee", foreign_key: "manager_id"
    belongs_to  :mentor,  class_name: "Employee", foreign_key: "mentor_id"
end
```

And the corresponding `has_many` association each gets a suffix to indicate
which one relation it refers to:

```ruby
class Employee < ActiveRecord::Base
    has_many :interns_as_manager, class_name: "Intern", foreign_key: "manager_id"
    has_many :interns_as_mentor,  class_name: "Intern", foreign_key: "mentor_id"
end
```

### Special case for trees

If your forward relation is named "parent", SchemaAssociations names the
reverse relation "child" or "children".  That is, if you have:

```ruby
create_table :nodes
    t.integer :parent_id         # schema_plus assumes it's a reference to this table
end
```

Then SchemaAssociations will define

```ruby
class Node < ActiveRecord::Base
    belongs_to :parent, class_name: "Node", foreign_key: "parent_id"
    has_many :children, class_name: "Node", foreign_key: "parent_id"
end
```

### Concise names

For modularity in your tables and classes, you might  use a common prefix for
related objects.  For example, you may have widgets each of which has a color, and each widget might have one frob that has a top color and a bottom color--all from the same set of colors.

```ruby
create_table :widget_colors |t|
end

create_table :widgets do |t|
    t.integer   :widget_color_id
end

create_table :widget_frobs
    t.integer :widget_id, index: :unique
    t.integer :top_widget_color_id,    references: :widget_colors
    t.integer :bottom_widget_color_id, references: :widget_colors
end
```

Using the full name for the associations would make your code verbose and not
quite DRY:

```ruby
@widget.widget_color
@widget.widget_frob.top_widget_color
```

Instead, by default, SchemaAssociations uses concise names: shared leading
words are removed from the association name.  So instead of the above, your
code looks like:

```ruby
@widget.color
@widget.frob.top_color
```

i.e. these associations would be defined:

```ruby
class WidgetColor < ActiveRecord::Base
    has_many :widgets,         class_name: "Widget",     foreign_key: "widget_color_id"
    has_many :frobs_as_top,    class_name: "WidgetFrob", foreign_key: "top_widget_color_id"
    has_many :frobs_as_bottom, class_name: "WidgetFrob", foreign_key: "bottom_widget_color_id"
end

class Widget < ActiveRecord::Base
    belongs_to :color, class_name: "WidgetColor", foreign_key: "widget_color_id"
    has_one    :frob,  class_name: "WidgetFrob",  foreign_key: "widget_frob_id"
end

class WidgetFrob < ActiveRecord::Base
    belongs_to :top_color,    class_name: "WidgetColor", foreign_key: "top_widget_color_id"
    belongs_to :bottom_color, class_name: "WidgetColor", foreign_key: "bottom_widget_color_id"
    belongs_to :widget,       class_name: "Widget",      foreign_key: "widget_id"
end
```

If you like the formality of using full names for the asociations, you can
turn off concise names globally or per-model, see [Configuration](#configuration).

### Ordering `has_many` using `position`

If the target of a `has_many` association has a column named `position`,
SchemaAssociations will specify `order: :position` for the association.
That is,

```ruby
create_table :comments do |t|
    t.integer post_id
    t.integer position
end
```

leads to

```ruby
class Post < ActiveRecord::Base
    has_many :comments, order: :position
end
```

## Table names, model class names, and modules

SchemaAssociations determines the model class name from the table name using the same convention (and helpers) that ActiveRecord uses.  But sometimes you might be doing things differently.  For example, in an engine you might have a prefix that goes in front of all table names, and the models might all be namespaced in a module.

To that end, SchemaAssociations lets you configure mappings from a table name prefix to a model class name prefix to use instead.  For example, suppose your database had tables:

```ruby
hpy_campers
hpy_go_lucky
```

The default model class names would be

```ruby
HpyCampers
HpyGoLucky
```

But if instead you wanted

```ruby
Happy::Campers
Happy::GoLucky
```
    
you would define the mapping in the [configuration](#configuration):

```ruby
SchemaPlus.setup do |config|
    config.table_prefix_map["hpy_"] = "Happy::"
end
```

Tables names that don't start with `hpy_` will continue to use the default determination.

You can set up multiple mappings.  E.g. if you're using several engines they can each set up the mapping for their own modules.

You can set up a mapping from or to the empty string, in order to unconditionally add or remove prefixes from all model class names.


## How do I know what it did?

If you're curious (or dubious) about what associations SchemaAssociations
defines, you can check the log file.  For every assocation that
SchemaAssociations defines, it generates a debug entry such as

    [schema_associations] Post.has_many :comments, :class_name "Comment", :foreign_key "comment_id"

which shows the exact method definition call.


SchemaAssociations defines the associations lazily, only creating them when
they're first needed.  So you may need to search through the log file to find
them all (and some may not be defined at all if they were never needed for the
use cases that you logged).

## Configuration

You can configure options globally in an initializer such as `config/initializers/schema_associations.rb`, e.g.

```ruby
SchemaAssociations.setup do |config|
  config.concise_names = false
end
```

and/or override the options per-model, e.g.:

```ruby
class MyModel < ActiveRecord::Base
  schema_associations.config concise_names: false
end
```

Here's the full list of options, with their default values:

```ruby
SchemaAssociations.setup do |config|

  # Enable/disable SchemaAssociations' automatic behavior
  config.auto_create = true
  
  # Whether to use concise naming (strip out common prefixes from class names)
  config.concise_names = true
  
  # List of association names to exclude from automatic creation.
  # Value is a single name, an array of names, or nil.
  config.except = nil
  
  # List of association names to include in automatic creation.
  # Value is a single name, and array of names, or nil.
  config.only = nil

  # List of association types to exclude from automatic creation.
  # Value is one or an array of :belongs_to, :has_many, :has_one, and/or
  # :has_and_belongs_to_many, or nil.
  config.except_type = nil

  # List of association types to include in automatic creation.
  # Value is one or an array of :belongs_to, :has_many, :has_one, and/or
  # :has_and_belongs_to_many, or nil.
  config.only_type = nil

  # Hash whose keys are possible matches at the start of table names, and
  # whose corresponding values are the prefix to use in front of class
  # names.
  config.table_prefix_map = {}
end
```


## Compatibility

SchemaAssociations is tested on all combinations of:

<!-- SCHEMA_DEV: MATRIX - begin -->
<!-- These lines are auto-generated by schema_dev based on schema_dev.yml -->
* ruby **2.3.1** with activerecord **4.2**, using **mysql2**, **postgresql** or **sqlite3**
* ruby **2.3.1** with activerecord **5.0**, using **mysql2**, **postgresql** or **sqlite3**
* ruby **2.3.1** with activerecord **5.1**, using **mysql2**, **postgresql** or **sqlite3**
* ruby **2.3.1** with activerecord **5.2**, using **mysql2**, **postgresql** or **sqlite3**

<!-- SCHEMA_DEV: MATRIX - end -->
    
Notes:

* As of version 1.2.3, rails < 4.1 and ruby < 2.1 are no longer supported
* As of version 1.2.0, ruby 1.9.2 is no longer supported.
* As of version 1.0.0, ruby 1.8.7 and rails < 3.2 are no longer supported.

## Installation

Install from http://rubygems.org via

    $ gem install "schema_associations"

or in a Gemfile

    gem "schema_associations"

## Testing

SchemaAssociations is tested against the matrix of combinations.  To run the full combo of
tests, after you've forked & cloned:

    $ cd schema_associations
    $ schema_dev bundle install
    $ schema_dev rspec

For more info, see [schema_dev](https://github.com/SchemaPlus/schema_dev)

Code coverage results will be in coverage/index.html -- it should be at 100% coverage.

## Release notes:

### 1.2.6

* Support for AR5 (Rails 5).

### 1.2.5

* Use schema_monkey rather than Railties.

### 1.2.4

* Bug fix: Don't fail trying to do associations for abstract classes (mysql2 only).  [#11, #12] Thanks to [@dmeranda](https://github.com/dmeranda)

### 1.2.3

* Use schema_plus_foreign_keys rather than all of schema_plus, to eliminate unneeded dependancies.  That limits us to AR >= 4.1 and ruby >= 2.1
* Fix deprecations
* Logging is now at `debug` level rather than `info` level

### 1.2.2

* Bug fix (Rails workaround) for STI: propagate associations to subclasses, since Rails might not, depending on the load order.

### 1.2.1

* Works with Rails 4.1
* Test against MRI ruby 2.1.2

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
