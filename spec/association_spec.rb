
require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe ActiveRecord::Base do

  after(:each) do
    remove_all_models
  end

  context "in basic case" do
    before(:each) do
      create_tables(
        "posts", {}, {},
        "comments", {}, { :post_id => {} }
      )
      class Post < ActiveRecord::Base ; end
      class Comment < ActiveRecord::Base ; end
    end

    it "should create belongs_to association when reflecting on it" do
      reflection = Comment.reflect_on_association(:post)
      reflection.should_not be_nil
      reflection.macro.should == :belongs_to
      reflection.options[:class_name].should == "Post"
      reflection.options[:foreign_key].should == "post_id"
      reflection.options[:inverse_of].should == :comments
    end

    it "should create association when reflecting on all associations" do
      reflection = Comment.reflect_on_all_associations.first
      reflection.should_not be_nil
      reflection.macro.should == :belongs_to
      reflection.options[:class_name].should == "Post"
      reflection.options[:foreign_key].should == "post_id"
      reflection.options[:inverse_of].should == :comments
    end

    it "should create association when accessing it" do
      post = Post.create
      comment = Comment.create(:post_id => post.id)
      comment.post.id.should == post.id
    end

    it "should create association when creating record" do
      post = Post.create
      comment = Comment.create(:post => post)
      comment.reload.post.id.should == post.id
    end

    it "should create has_many association" do
      reflection = Post.reflect_on_association(:comments)
      reflection.should_not be_nil
      reflection.macro.should == :has_many
      reflection.options[:class_name].should == "Comment"
      reflection.options[:foreign_key].should == "post_id"
      reflection.options[:inverse_of].should == :post
    end
    it "shouldn't raise an exception when model is instantiated" do
      expect { Post.new }.to_not raise_error
    end
  end

  context "with multiple associations of all types" do
    before(:each) do
      create_tables(
        "owners", {}, {},
        "colors", {}, {},
        "widgets", {}, {
          :owner_id => {},
        },
        "parts", {}, { :widget_id => {} },
        "manifests", {}, { :widget_id => { :index => {:unique => true}} },
        "colors_widgets", {:id => false}, { :widget_id => {}, :color_id => {} }
      )
    end

    def check_reflections(hash)
      hash.each do |key, val|
        reflection = Widget.reflect_on_association(key)
        case val
        when true then reflection.should_not be_nil
        else           reflection.should be_nil
        end
      end
    end

    it "should default as expected" do
      class Widget < ActiveRecord::Base ; end
      check_reflections(:owner => true, :colors => true, :parts => true, :manifest => true)
    end

    it "should respect :only" do 
      class Widget < ActiveRecord::Base
        schema_associations :only => :owner
      end
      check_reflections(:owner => true, :colors => false, :parts => false, :manifest => false)
    end

    it "should respect :except" do 
      class Widget < ActiveRecord::Base
        schema_associations :except => :owner
      end
      check_reflections(:owner => false, :colors => true, :parts => true, :manifest => true)
    end

    it "should respect :only_type :belongs_to" do 
      class Widget < ActiveRecord::Base
        schema_associations :only_type => :belongs_to
      end
      check_reflections(:owner => true, :colors => false, :parts => false, :manifest => false)
    end

    it "should respect :except_type :belongs_to" do 
      class Widget < ActiveRecord::Base
        schema_associations :except_type => :belongs_to
      end
      check_reflections(:owner => false, :colors => true, :parts => true, :manifest => true)
    end

    it "should respect :only_type :has_many" do 
      class Widget < ActiveRecord::Base
        schema_associations :only_type => :has_many
      end
      check_reflections(:owner => false, :colors => false, :parts => true, :manifest => false)
    end

    it "should respect :except_type :has_many" do 
      class Widget < ActiveRecord::Base
        schema_associations :except_type => :has_many
      end
      check_reflections(:owner => true, :colors => true, :parts => false, :manifest => true)
    end

    it "should respect :only_type :has_one" do 
      class Widget < ActiveRecord::Base
        schema_associations :only_type => :has_one
      end
      check_reflections(:owner => false, :colors => false, :parts => false, :manifest => true)
    end

    it "should respect :except_type :has_one" do 
      class Widget < ActiveRecord::Base
        schema_associations :except_type => :has_one
      end
      check_reflections(:owner => true, :colors => true, :parts => true, :manifest => false)
    end

    it "should respect :only_type :has_and_belongs_to_many" do 
      class Widget < ActiveRecord::Base
        schema_associations :only_type => :has_and_belongs_to_many
      end
      check_reflections(:owner => false, :colors => true, :parts => false, :manifest => false)
    end

    it "should respect :except_type :has_and_belongs_to_many" do 
      class Widget < ActiveRecord::Base
        schema_associations :except_type => :has_and_belongs_to_many
      end
      check_reflections(:owner => true, :colors => false, :parts => true, :manifest => true)
    end

  end

  context "overrides" do
    it "should override auto_create negatively" do
      with_associations_auto_create(true) do
        create_tables(
          "posts", {}, {},
          "comments", {}, { :post_id => {} }
        )
        class Post < ActiveRecord::Base
          schema_associations :auto_create => false
        end
        class Comment < ActiveRecord::Base ; end
        Post.reflect_on_association(:comments).should be_nil
        Comment.reflect_on_association(:post).should_not be_nil
      end
    end


    it "should override auto_create positively explicitly" do
      with_associations_auto_create(false) do
        create_tables(
          "posts", {}, {},
          "comments", {}, { :post_id => {} }
        )
        class Post < ActiveRecord::Base
          schema_associations :auto_create => true
        end
        class Comment < ActiveRecord::Base ; end
        Post.reflect_on_association(:comments).should_not be_nil
        Comment.reflect_on_association(:post).should be_nil
      end
    end

    it "should override auto_create positively implicitly" do
      with_associations_auto_create(false) do
        create_tables(
          "posts", {}, {},
          "comments", {}, { :post_id => {} }
        )
        class Post < ActiveRecord::Base
          schema_associations
        end
        class Comment < ActiveRecord::Base ; end
        Post.reflect_on_association(:comments).should_not be_nil
        Comment.reflect_on_association(:post).should be_nil
      end
    end
  end


  context "with unique index" do
    before(:each) do
      create_tables(
        "posts", {}, {},
        "comments", {}, { :post_id => {:index => { :unique => true} } }
      )
      class Post < ActiveRecord::Base ; end
      class Comment < ActiveRecord::Base ; end
    end
    it "should create has_one association" do
      reflection = Post.reflect_on_association(:comment)
      reflection.should_not be_nil
      reflection.macro.should == :has_one
      reflection.options[:class_name].should == "Comment"
      reflection.options[:foreign_key].should == "post_id"
      reflection.options[:inverse_of].should == :post
    end
    it "should create belongs_to association with singular inverse" do
      reflection = Comment.reflect_on_association(:post)
      reflection.should_not be_nil
      reflection.macro.should == :belongs_to
      reflection.options[:class_name].should == "Post"
      reflection.options[:foreign_key].should == "post_id"
      reflection.options[:inverse_of].should == :comment
    end
  end

  context "with prefixed column names" do
    before(:each) do
      create_tables(
        "posts", {}, {},
        "comments", {}, { :subject_post_id => { :references => :posts} }
      )
      class Post < ActiveRecord::Base ; end
      class Comment < ActiveRecord::Base ; end
    end
    it "should name belongs_to according to column" do
      reflection = Comment.reflect_on_association(:subject_post)
      reflection.should_not be_nil
      reflection.macro.should == :belongs_to
      reflection.options[:class_name].should == "Post"
      reflection.options[:foreign_key].should == "subject_post_id"
      reflection.options[:inverse_of].should == :comments_as_subject
    end

    it "should name has_many using 'as column'" do
      reflection = Post.reflect_on_association(:comments_as_subject)
      reflection.should_not be_nil
      reflection.macro.should == :has_many
      reflection.options[:class_name].should == "Comment"
      reflection.options[:foreign_key].should == "subject_post_id"
      reflection.options[:inverse_of].should == :subject_post
    end
  end

  context "with suffixed column names" do
    before(:each) do
      create_tables(
        "posts", {}, {},
        "comments", {}, { :post_cited => { :references => :posts} }
      )
      class Post < ActiveRecord::Base ; end
      class Comment < ActiveRecord::Base ; end
    end
    it "should name belongs_to according to column" do
      reflection = Comment.reflect_on_association(:post_cited)
      reflection.should_not be_nil
      reflection.macro.should == :belongs_to
      reflection.options[:class_name].should == "Post"
      reflection.options[:foreign_key].should == "post_cited"
      reflection.options[:inverse_of].should == :comments_as_cited
    end

    it "should name has_many using 'as column'" do
      reflection = Post.reflect_on_association(:comments_as_cited)
      reflection.should_not be_nil
      reflection.macro.should == :has_many
      reflection.options[:class_name].should == "Comment"
      reflection.options[:foreign_key].should == "post_cited"
      reflection.options[:inverse_of].should == :post_cited
    end
  end

  context "with arbitrary column names" do
    before(:each) do
      create_tables(
        "posts", {}, {},
        "comments", {}, { :subject => {:references => :posts} }
      )
      class Post < ActiveRecord::Base ; end
      class Comment < ActiveRecord::Base ; end
    end
    it "should name belongs_to according to column" do
      reflection = Comment.reflect_on_association(:subject)
      reflection.should_not be_nil
      reflection.macro.should == :belongs_to
      reflection.options[:class_name].should == "Post"
      reflection.options[:foreign_key].should == "subject"
      reflection.options[:inverse_of].should == :comments_as_subject
    end

    it "should name has_many using 'as column'" do
      reflection = Post.reflect_on_association(:comments_as_subject)
      reflection.should_not be_nil
      reflection.macro.should == :has_many
      reflection.options[:class_name].should == "Comment"
      reflection.options[:foreign_key].should == "subject"
      reflection.options[:inverse_of].should == :subject
    end
  end

  it "maps table prefix" do
    with_associations_config(:table_prefix_map => { "wooga_" => "Happy"} ) do
      create_tables(
        "wooga_posts", {}, {},
        "wooga_comments", {}, { :wooga_post_id => { :references => :wooga_posts} }
      )
      class HappyPost < ActiveRecord::Base ; self.table_name = 'wooga_posts' ; end
      class HappyComment < ActiveRecord::Base ; self.table_name = 'wooga_comments' ; end
      # Kernel.warn HappyPost.reflect_on_all_associations.inspect
      HappyComment.reflect_on_association(:post).class_name.should == "HappyPost"
      HappyPost.reflect_on_association(:comments).class_name.should == "HappyComment"
    end
  end

  context "without position" do
    before(:each) do
      create_tables(
        "posts", {}, {},
        "comments", {}, { :post_id => {} }
      )
      class Post < ActiveRecord::Base ; end
      class Comment < ActiveRecord::Base ; end
    end
    it "should create unordered has_many association" do
      reflection = Post.reflect_on_association(:comments)
      reflection.should_not be_nil
      reflection.macro.should == :has_many
      reflection.options[:class_name].should == "Comment"
      reflection.options[:foreign_key].should == "post_id"
      reflection.options[:inverse_of].should == :post
      if ::ActiveRecord::VERSION::MAJOR.to_i < 4
        reflection.options[:order].should be_nil
      else
        reflection.scope.should be_nil
      end
    end
  end

  context "with position" do
    before(:each) do
      create_tables(
        "posts", {}, {},
        "comments", {}, { :post_id => {}, :position => {} }
      )
      class Post < ActiveRecord::Base ; end
      class Comment < ActiveRecord::Base ; end
    end
    it "should create ordered has_many association" do
      reflection = Post.reflect_on_association(:comments)
      reflection.should_not be_nil
      reflection.macro.should == :has_many
      reflection.options[:class_name].should == "Comment"
      reflection.options[:foreign_key].should == "post_id"
      reflection.options[:inverse_of].should == :post
      if ::ActiveRecord::VERSION::MAJOR.to_i < 4
        reflection.options[:order].to_s.should == "position"
      else
        reflection.scope.should_not be_nil
        scope_tester = Object.new
        expect(scope_tester).to receive(:order).with(:position)
        scope_tester.instance_exec(&reflection.scope)
      end
    end
  end

  context "with scope that doesn't use include" do
    before(:each) do
      create_tables(
        "posts", {}, {},
        "comments", {}, { :post_id => {}, :position => {} }
      )
      class Post < ActiveRecord::Base ; end
      class Comment < ActiveRecord::Base
        scope :simple_scope, lambda { order(:id) }
      end
    end
    it "should create viable scope" do
      relation = Comment.simple_scope
      expect { relation.to_a }.to_not raise_error
    end
  end

  context "with scope that uses include" do
    before(:each) do
      create_tables(
        "posts", {}, {},
        "comments", {}, { :post_id => {}, :position => {} }
      )
      class Post < ActiveRecord::Base ; end
      class Comment < ActiveRecord::Base
        scope :simple_scope, lambda { order(:id).includes(:post) }
      end
    end
    it "should create viable scope" do
      relation = Comment.simple_scope
      expect { relation.to_a }.to_not raise_error
    end
  end

  context "regarding parent-child relationships" do

    let (:migration) {ActiveRecord::Migration}

    before(:each) do
      create_tables(
        "nodes", {:foreign_keys => {:auto_index => false}}, { :parent_id => {} }
      )
    end

    it "should use children as the inverse of parent" do
      class Node < ActiveRecord::Base ; end
      reflection = Node.reflect_on_association(:children)
      reflection.should_not be_nil
    end

    it "should use child as the singular inverse of parent" do
      migration.suppress_messages do
        migration.add_index(:nodes, :parent_id, :unique => true)
      end
      class Node < ActiveRecord::Base ; end
      reflection = Node.reflect_on_association(:child)
      reflection.should_not be_nil
    end
  end


  context "regarding concise names" do

    def prefix_one
      create_tables(
        "posts", {}, {},
        "post_comments", {}, { :post_id => {} }
      )
      Object.const_set(:Post, Class.new(ActiveRecord::Base))
      Object.const_set(:PostComment, Class.new(ActiveRecord::Base))
    end

    def suffix_one
      create_tables(
        "posts", {}, {},
        "comment_posts", {}, { :post_id => {} }
      )
      Object.const_set(:Post, Class.new(ActiveRecord::Base))
      Object.const_set(:CommentPost, Class.new(ActiveRecord::Base))
    end

    def prefix_both
      create_tables(
        "blog_page_posts", {}, {},
        "blog_page_comments", {}, { :blog_page_post_id => {} }
      )
      Object.const_set(:BlogPagePost, Class.new(ActiveRecord::Base))
      Object.const_set(:BlogPageComment, Class.new(ActiveRecord::Base))
    end

    it "should use concise association name for one prefix" do
      with_associations_config(:auto_create => true, :concise_names => true) do
        prefix_one
        reflection = Post.reflect_on_association(:comments)
        reflection.should_not be_nil
        reflection.macro.should == :has_many
        reflection.options[:class_name].should == "PostComment"
        reflection.options[:foreign_key].should == "post_id"
        reflection.options[:inverse_of].should == :post
      end
    end

    it "should use concise association name for one suffix" do
      with_associations_config(:auto_create => true, :concise_names => true) do
        suffix_one
        reflection = Post.reflect_on_association(:comments)
        reflection.should_not be_nil
        reflection.macro.should == :has_many
        reflection.options[:class_name].should == "CommentPost"
        reflection.options[:foreign_key].should == "post_id"
        reflection.options[:inverse_of].should == :post
      end
    end

    it "should use concise association name for shared prefixes" do
      with_associations_config(:auto_create => true, :concise_names => true) do
        prefix_both
        reflection = BlogPagePost.reflect_on_association(:comments)
        reflection.should_not be_nil
        reflection.macro.should == :has_many
        reflection.options[:class_name].should == "BlogPageComment"
        reflection.options[:foreign_key].should == "blog_page_post_id"
        reflection.options[:inverse_of].should == :post
      end
    end

    it "should use full names and not concise names when so configured" do
      with_associations_config(:auto_create => true, :concise_names => false) do
        prefix_one
        reflection = Post.reflect_on_association(:post_comments)
        reflection.should_not be_nil
        reflection.macro.should == :has_many
        reflection.options[:class_name].should == "PostComment"
        reflection.options[:foreign_key].should == "post_id"
        reflection.options[:inverse_of].should == :post
        reflection = Post.reflect_on_association(:comments)
        reflection.should be_nil
      end
    end

    it "should use concise names and not full names when so configured" do
      with_associations_config(:auto_create => true, :concise_names => true) do
        prefix_one
        reflection = Post.reflect_on_association(:comments)
        reflection.should_not be_nil
        reflection.macro.should == :has_many
        reflection.options[:class_name].should == "PostComment"
        reflection.options[:foreign_key].should == "post_id"
        reflection.options[:inverse_of].should == :post
        reflection = Post.reflect_on_association(:post_comments)
        reflection.should be_nil
      end
    end


  end

  context "with joins table" do
    before(:each) do
      create_tables(
        "posts", {}, {},
        "tags", {}, {},
        "posts_tags", {:id => false}, { :post_id => {}, :tag_id => {}}
      )
      class Post < ActiveRecord::Base ; end
      class Tag < ActiveRecord::Base ; end
    end
    it "should create has_and_belongs_to_many association" do
      reflection = Post.reflect_on_association(:tags)
      reflection.should_not be_nil
      reflection.macro.should == :has_and_belongs_to_many
      reflection.options[:class_name].should == "Tag"
      reflection.options[:join_table].should == "posts_tags"
    end
  end

  context "regarding existing methods" do
    before(:each) do
      create_tables(
        "types", {}, {},
        "posts", {}, {:type_id => {}}
      )
    end
    it "should define association normally if no existing method is defined" do
      class Type < ActiveRecord::Base ; end
      Type.reflect_on_association(:posts).should_not be_nil # sanity check for this context
    end
    it "should not define association over existing public method" do
      class Type < ActiveRecord::Base
        def posts
          :existing
        end
      end
      Type.reflect_on_association(:posts).should be_nil
    end
    it "should not define association over existing private method" do
      class Type < ActiveRecord::Base
        private
        def posts
          :existing
        end
      end
      Type.reflect_on_association(:posts).should be_nil
    end
    it "should define association :type over (deprecated) kernel method" do
      class Post < ActiveRecord::Base ; end
      Post.reflect_on_association(:type).should_not be_nil
    end
    it "should not define association :type over model method" do
      class Post < ActiveRecord::Base
        def type
          :existing
        end
      end
      Post.reflect_on_association(:type).should be_nil
    end
  end

  if defined? ::ActiveRecord::Relation

    context "regarding relations" do
      before(:each) do
        create_tables(
          "posts", {}, {},
          "comments", {}, { :post_id => {} }
        )
        class Post < ActiveRecord::Base ; end
        class Comment < ActiveRecord::Base ; end
      end

      it "should define associations before needed by relation" do
        expect { Post.joins(:comments).to_a }.to_not raise_error
      end
    end
  end

  protected

  def with_associations_auto_create(value, &block)
    with_associations_config(:auto_create => value, &block)
  end

  def with_associations_config(opts, &block)
    save = Hash[opts.keys.collect{|key| [key, SchemaAssociations.config.send(key)]}]
    begin
      SchemaAssociations.setup do |config|
        config.update_attributes(opts)
      end
      yield
    ensure
      SchemaAssociations.config.update_attributes(save)
    end
  end

  def create_tables(*table_defs)
    ActiveRecord::Migration.suppress_messages do
      ActiveRecord::Base.connection.tables.each do |table|
        ActiveRecord::Migration.drop_table table
      end
      table_defs.each_slice(3) do |table_name, opts, columns_with_options|
        ActiveRecord::Migration.create_table table_name, opts do |t|
          columns_with_options.each_pair do |column, options|
            t.integer column, options
          end
        end
      end
    end
  end

end
