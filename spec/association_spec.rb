# frozen_string_literal: true

require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe ActiveRecord::Base do
  def stub_model(name, base = ActiveRecord::Base, &block)
    klass = Class.new(base)

    if block_given?
      klass.instance_eval(&block)
    end

    stub_const(name, klass)
  end

  context "in basic case" do
    before(:each) do
      create_tables(
        "posts", {}, {},
        "comments", {}, { post_id: {foreign_key: true} }
      )
      stub_model('Post')
      stub_model('Comment')
    end

    it "should create belongs_to association when reflecting on it" do
      reflection = Comment.reflect_on_association(:post)
      expect(reflection).not_to be_nil
      expect(reflection.macro).to eq(:belongs_to)
      expect(reflection.options[:class_name]).to eq("Post")
      expect(reflection.options[:foreign_key]).to eq("post_id")
      expect(reflection.options[:inverse_of]).to eq(:comments)
    end

    it "should create association when reflecting on all associations" do
      reflection = Comment.reflect_on_all_associations.first
      expect(reflection).not_to be_nil
      expect(reflection.macro).to eq(:belongs_to)
      expect(reflection.options[:class_name]).to eq("Post")
      expect(reflection.options[:foreign_key]).to eq("post_id")
      expect(reflection.options[:inverse_of]).to eq(:comments)
    end

    it "should create association when accepts_nested_attributes_for is called" do
      expect {
        Post.class_eval { accepts_nested_attributes_for :comments }
      }.to_not raise_error
    end

    it "should create association when accessing it" do
      post = Post.create
      comment = Comment.create(post_id: post.id)
      expect(comment.post.id).to eq(post.id)
    end

    it "should create association when creating record" do
      post = Post.create
      comment = Comment.create(post: post)
      expect(comment.reload.post.id).to eq(post.id)
    end

    it "should create has_many association" do
      reflection = Post.reflect_on_association(:comments)
      expect(reflection).not_to be_nil
      expect(reflection.macro).to eq(:has_many)
      expect(reflection.options[:class_name]).to eq("Comment")
      expect(reflection.options[:foreign_key]).to eq("post_id")
      expect(reflection.options[:inverse_of]).to eq(:post)
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
          owner_id: { foreign_key: true },
        },
        "parts", {}, { widget_id: { foreign_key: true } },
        "manifests", {}, { widget_id: { foreign_key: true, index: {unique: true}} },
        "colors_widgets", {id: false}, { widget_id: { foreign_key: true}, color_id: { foreign_key: true} }
      )
    end

    def check_reflections(hash)
      hash.each do |key, val|
        reflection = Widget.reflect_on_association(key)
        case val
        when true then expect(reflection).not_to be_nil
        else           expect(reflection).to be_nil
        end
      end
    end

    it "should default as expected" do
      stub_model('Widget')
      check_reflections(owner: true, colors: true, parts: true, manifest: true)
    end

    it "should respect :only" do
      stub_model('Widget') do
        schema_associations only: :owner
      end
      check_reflections(owner: true, colors: false, parts: false, manifest: false)
    end

    it "should respect :except" do
      stub_model('Widget') do
        schema_associations except: :owner
      end
      check_reflections(owner: false, colors: true, parts: true, manifest: true)
    end

    it "should respect :only_type :belongs_to" do
      stub_model('Widget') do
        schema_associations only_type: :belongs_to
      end
      check_reflections(owner: true, colors: false, parts: false, manifest: false)
    end

    it "should respect :except_type :belongs_to" do
      stub_model('Widget') do
        schema_associations except_type: :belongs_to
      end
      check_reflections(owner: false, colors: true, parts: true, manifest: true)
    end

    it "should respect :only_type :has_many" do
      stub_model('Widget') do
        schema_associations only_type: :has_many
      end
      check_reflections(owner: false, colors: false, parts: true, manifest: false)
    end

    it "should respect :except_type :has_many" do
      stub_model('Widget') do
        schema_associations except_type: :has_many
      end
      check_reflections(owner: true, colors: true, parts: false, manifest: true)
    end

    it "should respect :only_type :has_one" do
      stub_model('Widget') do
        schema_associations only_type: :has_one
      end
      check_reflections(owner: false, colors: false, parts: false, manifest: true)
    end

    it "should respect :except_type :has_one" do
      stub_model('Widget') do
        schema_associations except_type: :has_one
      end
      check_reflections(owner: true, colors: true, parts: true, manifest: false)
    end

    it "should respect :only_type :has_and_belongs_to_many" do
      stub_model('Widget') do
        schema_associations only_type: :has_and_belongs_to_many
      end
      check_reflections(owner: false, colors: true, parts: false, manifest: false)
    end

    it "should respect :except_type :has_and_belongs_to_many" do
      stub_model('Widget') do
        schema_associations except_type: :has_and_belongs_to_many
      end
      check_reflections(owner: true, colors: false, parts: true, manifest: true)
    end

  end

  context "overrides" do
    it "should override auto_create negatively" do
      with_associations_auto_create(true) do
        create_tables(
          "posts", {}, {},
          "comments", {}, { post_id: {foreign_key: true} }
        )
        stub_model('Post') do
          schema_associations auto_create: false
        end
        stub_model('Comment')
        expect(Post.reflect_on_association(:comments)).to be_nil
        expect(Comment.reflect_on_association(:post)).not_to be_nil
      end
    end


    it "should override auto_create positively explicitly" do
      with_associations_auto_create(false) do
        create_tables(
          "posts", {}, {},
          "comments", {}, { post_id: {foreign_key: true} }
        )
        stub_model('Post') do
          schema_associations auto_create: true
        end
        stub_model('Comment')
        expect(Post.reflect_on_association(:comments)).not_to be_nil
        expect(Comment.reflect_on_association(:post)).to be_nil
      end
    end

    it "should override auto_create positively implicitly" do
      with_associations_auto_create(false) do
        create_tables(
          "posts", {}, {},
          "comments", {}, { post_id: {foreign_key: true} }
        )
        stub_model('Post') do
          schema_associations
        end
        stub_model('Comment')
        expect(Post.reflect_on_association(:comments)).not_to be_nil
        expect(Comment.reflect_on_association(:post)).to be_nil
      end
    end
  end


  context "with unique index" do
    before(:each) do
      create_tables(
        "posts", {}, {},
        "comments", {}, { post_id: {foreign_key: true, index: { unique: true} } }
      )
      stub_model('Post')
      stub_model('Comment')
    end
    it "should create has_one association" do
      reflection = Post.reflect_on_association(:comment)
      expect(reflection).not_to be_nil
      expect(reflection.macro).to eq(:has_one)
      expect(reflection.options[:class_name]).to eq("Comment")
      expect(reflection.options[:foreign_key]).to eq("post_id")
      expect(reflection.options[:inverse_of]).to eq(:post)
    end
    it "should create belongs_to association with singular inverse" do
      reflection = Comment.reflect_on_association(:post)
      expect(reflection).not_to be_nil
      expect(reflection.macro).to eq(:belongs_to)
      expect(reflection.options[:class_name]).to eq("Post")
      expect(reflection.options[:foreign_key]).to eq("post_id")
      expect(reflection.options[:inverse_of]).to eq(:comment)
    end
  end

  context "with prefixed column names" do
    before(:each) do
      create_tables(
        "posts", {}, {},
        "comments", {}, { subject_post_id: { foreign_key: { references: "posts" }} }
      )
      stub_model('Post')
      stub_model('Comment')
    end
    it "should name belongs_to according to column" do
      reflection = Comment.reflect_on_association(:subject_post)
      expect(reflection).not_to be_nil
      expect(reflection.macro).to eq(:belongs_to)
      expect(reflection.options[:class_name]).to eq("Post")
      expect(reflection.options[:foreign_key]).to eq("subject_post_id")
      expect(reflection.options[:inverse_of]).to eq(:comments_as_subject)
    end

    it "should name has_many using 'as column'" do
      reflection = Post.reflect_on_association(:comments_as_subject)
      expect(reflection).not_to be_nil
      expect(reflection.macro).to eq(:has_many)
      expect(reflection.options[:class_name]).to eq("Comment")
      expect(reflection.options[:foreign_key]).to eq("subject_post_id")
      expect(reflection.options[:inverse_of]).to eq(:subject_post)
    end
  end

  context "with suffixed column names" do
    before(:each) do
      create_tables(
        "posts", {}, {},
        "comments", {}, { post_cited: { foreign_key: {references: "posts" }} }
      )
      stub_model('Post')
      stub_model('Comment')
    end
    it "should name belongs_to according to column" do
      reflection = Comment.reflect_on_association(:post_cited)
      expect(reflection).not_to be_nil
      expect(reflection.macro).to eq(:belongs_to)
      expect(reflection.options[:class_name]).to eq("Post")
      expect(reflection.options[:foreign_key]).to eq("post_cited")
      expect(reflection.options[:inverse_of]).to eq(:comments_as_cited)
    end

    it "should name has_many using 'as column'" do
      reflection = Post.reflect_on_association(:comments_as_cited)
      expect(reflection).not_to be_nil
      expect(reflection.macro).to eq(:has_many)
      expect(reflection.options[:class_name]).to eq("Comment")
      expect(reflection.options[:foreign_key]).to eq("post_cited")
      expect(reflection.options[:inverse_of]).to eq(:post_cited)
    end
  end

  context "with arbitrary column names" do
    before(:each) do
      create_tables(
        "posts", {}, {},
        "comments", {}, { subject: {foreign_key: { references: "posts" }} }
      )
      stub_model('Post')
      stub_model('Comment')
    end
    it "should name belongs_to according to column" do
      reflection = Comment.reflect_on_association(:subject)
      expect(reflection).not_to be_nil
      expect(reflection.macro).to eq(:belongs_to)
      expect(reflection.options[:class_name]).to eq("Post")
      expect(reflection.options[:foreign_key]).to eq("subject")
      expect(reflection.options[:inverse_of]).to eq(:comments_as_subject)
    end

    it "should name has_many using 'as column'" do
      reflection = Post.reflect_on_association(:comments_as_subject)
      expect(reflection).not_to be_nil
      expect(reflection.macro).to eq(:has_many)
      expect(reflection.options[:class_name]).to eq("Comment")
      expect(reflection.options[:foreign_key]).to eq("subject")
      expect(reflection.options[:inverse_of]).to eq(:subject)
    end
  end

  it "maps table prefix" do
    with_associations_config(table_prefix_map: { "wooga_" => "Happy"} ) do
      create_tables(
        "wooga_posts", {}, {},
        "wooga_comments", {}, { wooga_post_id: { foreign_key: true} }
      )
      stub_model('HappyPost') do
        self.table_name = 'wooga_posts'
      end
      stub_model('HappyComment') do
        self.table_name = 'wooga_comments'
      end

      # Kernel.warn HappyPost.reflect_on_all_associations.inspect
      expect(HappyComment.reflect_on_association(:post).class_name).to eq("HappyPost")
      expect(HappyPost.reflect_on_association(:comments).class_name).to eq("HappyComment")
    end
  end

  context "without position" do
    before(:each) do
      create_tables(
        "posts", {}, {},
        "comments", {}, { post_id: { foreign_key: true} }
      )
      stub_model('Post')
      stub_model('Comment')
    end
    it "should create unordered has_many association" do
      reflection = Post.reflect_on_association(:comments)
      expect(reflection).not_to be_nil
      expect(reflection.macro).to eq(:has_many)
      expect(reflection.options[:class_name]).to eq("Comment")
      expect(reflection.options[:foreign_key]).to eq("post_id")
      expect(reflection.options[:inverse_of]).to eq(:post)
      expect(reflection.scope).to be_nil
    end
  end

  context "with position" do
    before(:each) do
      create_tables(
        "posts", {}, {},
        "comments", {}, { post_id: {foreign_key: true}, position: {} }
      )
      stub_model('Post')
      stub_model('Comment')
    end
    it "should create ordered has_many association" do
      reflection = Post.reflect_on_association(:comments)
      expect(reflection).not_to be_nil
      expect(reflection.macro).to eq(:has_many)
      expect(reflection.options[:class_name]).to eq("Comment")
      expect(reflection.options[:foreign_key]).to eq("post_id")
      expect(reflection.options[:inverse_of]).to eq(:post)
      expect(reflection.scope).not_to be_nil
      scope_tester = Object.new
      expect(scope_tester).to receive(:order).with(:position)
      scope_tester.instance_exec(&reflection.scope)
    end
  end

  context "with scope that doesn't use include" do
    before(:each) do
      create_tables(
        "posts", {}, {},
        "comments", {}, { post_id: {}, position: {} }
      )
      stub_model('Post')
      stub_model('Comment') do
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
        "comments", {}, { post_id: {}, position: {} }
      )
      stub_model('Post')
      stub_model('Comment') do
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
        "nodes", {}, { parent_id: { foreign_key: true} }
      )
    end

    it "should use children as the inverse of parent" do
      stub_model('Node')
      reflection = Node.reflect_on_association(:children)
      expect(reflection).not_to be_nil
    end

    it "should use child as the singular inverse of parent" do
      migration.suppress_messages do
        migration.add_index(:nodes, :parent_id, unique: true)
      end
      stub_model('Node')
      reflection = Node.reflect_on_association(:child)
      expect(reflection).not_to be_nil
    end
  end


  context "regarding concise names" do

    def prefix_one
      create_tables(
        "posts", {}, {},
        "post_comments", {}, { post_id: { foreign_key: true} }
      )
      stub_model('Post')
      stub_model('PostComment')
    end

    def suffix_one
      create_tables(
        "posts", {}, {},
        "comment_posts", {}, { post_id: { foreign_key: true} }
      )
      stub_model('Post')
      stub_model('PostComment')
    end

    def prefix_both
      create_tables(
        "blog_page_posts", {}, {},
        "blog_page_comments", {}, { blog_page_post_id: { foreign_key: true} }
      )
      stub_model('BlogPagePost')
      stub_model('BlogPageComment')
    end

    it "should use concise association name for one prefix" do
      with_associations_config(auto_create: true, concise_names: true) do
        prefix_one
        reflection = Post.reflect_on_association(:comments)
        expect(reflection).not_to be_nil
        expect(reflection.macro).to eq(:has_many)
        expect(reflection.options[:class_name]).to eq("PostComment")
        expect(reflection.options[:foreign_key]).to eq("post_id")
        expect(reflection.options[:inverse_of]).to eq(:post)
      end
    end

    it "should use concise association name for one suffix" do
      with_associations_config(auto_create: true, concise_names: true) do
        suffix_one
        reflection = Post.reflect_on_association(:comments)
        expect(reflection).not_to be_nil
        expect(reflection.macro).to eq(:has_many)
        expect(reflection.options[:class_name]).to eq("CommentPost")
        expect(reflection.options[:foreign_key]).to eq("post_id")
        expect(reflection.options[:inverse_of]).to eq(:post)
      end
    end

    it "should use concise association name for shared prefixes" do
      with_associations_config(auto_create: true, concise_names: true) do
        prefix_both
        reflection = BlogPagePost.reflect_on_association(:comments)
        expect(reflection).not_to be_nil
        expect(reflection.macro).to eq(:has_many)
        expect(reflection.options[:class_name]).to eq("BlogPageComment")
        expect(reflection.options[:foreign_key]).to eq("blog_page_post_id")
        expect(reflection.options[:inverse_of]).to eq(:post)
      end
    end

    it "should use full names and not concise names when so configured" do
      with_associations_config(auto_create: true, concise_names: false) do
        prefix_one
        reflection = Post.reflect_on_association(:post_comments)
        expect(reflection).not_to be_nil
        expect(reflection.macro).to eq(:has_many)
        expect(reflection.options[:class_name]).to eq("PostComment")
        expect(reflection.options[:foreign_key]).to eq("post_id")
        expect(reflection.options[:inverse_of]).to eq(:post)
        reflection = Post.reflect_on_association(:comments)
        expect(reflection).to be_nil
      end
    end

    it "should use concise names and not full names when so configured" do
      with_associations_config(auto_create: true, concise_names: true) do
        prefix_one
        reflection = Post.reflect_on_association(:comments)
        expect(reflection).not_to be_nil
        expect(reflection.macro).to eq(:has_many)
        expect(reflection.options[:class_name]).to eq("PostComment")
        expect(reflection.options[:foreign_key]).to eq("post_id")
        expect(reflection.options[:inverse_of]).to eq(:post)
        reflection = Post.reflect_on_association(:post_comments)
        expect(reflection).to be_nil
      end
    end


  end

  context "with joins table" do
    before(:each) do
      create_tables(
        "posts", {}, {},
        "tags", {}, {},
        "posts_tags", {id: false}, { post_id: { foreign_key: true}, tag_id: { foreign_key: true}}
      )
      stub_model('Post')
      stub_model('Tag')
    end
    it "should create has_and_belongs_to_many association" do
      reflection = Post.reflect_on_association(:tags)
      expect(reflection).not_to be_nil
      expect(reflection.macro).to eq(:has_and_belongs_to_many)
      expect(reflection.options[:class_name]).to eq("Tag")
      expect(reflection.options[:join_table]).to eq("posts_tags")
    end
  end

  context 'defining has_many through associations' do
    before(:each) do
      create_tables(
          "users", {}, {},
          "posts", {}, { user_id: { foreign_key: true}},
          "comments", {}, { post_id: { foreign_key: true}},
      )
      stub_model('Post')
      stub_model('Comment')
      stub_model('User') do
        has_many :comments, through: :posts
      end
    end

    it 'should not error when accessing the through association' do
      reflection = User.reflect_on_association(:posts)
      expect(reflection).not_to be_nil

      reflection = User.reflect_on_association(:comments)
      expect(reflection).not_to be_nil
      expect(reflection.macro).to eq(:has_many)
      expect(reflection.options[:through]).to eq(:posts)

      expect { User.new.comments }.to_not raise_error
    end
  end

  context "regarding existing methods" do
    before(:each) do
      create_tables(
        "types", {}, {},
        "posts", {}, {type_id: { foreign_key: true}}
      )
    end
    it "should define association normally if no existing method is defined" do
      stub_model('Type')
      expect(Type.reflect_on_association(:posts)).not_to be_nil # sanity check for this context
    end
    it "should not define association over existing public method" do
      stub_model('Type') do
        define_method(:posts) do
          :existing
        end
      end
      expect(Type.reflect_on_association(:posts)).to be_nil
    end
    it "should not define association over existing private method" do
      stub_model('Type') do
        define_method(:posts) do
          :existing
        end
        private :posts
      end
      expect(Type.reflect_on_association(:posts)).to be_nil
    end
    it "should define association :type over (deprecated) kernel method" do
      stub_model('Post')
      expect(Post.reflect_on_association(:type)).not_to be_nil
    end
    it "should not define association :type over model method" do
      stub_model('Post') do
        define_method(:type) do
          :existing
        end
      end
      expect(Post.reflect_on_association(:type)).to be_nil
    end
  end

  context "regarding STI" do
    before(:each) do
      create_tables(
        "posts", {}, {},
        "comments", {}, { post_id: { foreign_key: true}, type: {coltype: :string} },
        "citers", {}, {},
        "citations", {}, { comment_id: { foreign_key: true}, citer_id: { foreign_key: true}}
      )
      stub_model('Post')
      stub_model('Comment')
      stub_model('Citation')
      stub_model('SubComment', Comment)
      stub_model('OwnComment', Comment) do
        has_one :citer, through: :citations
      end
    end

    it "defines association for subclass" do
      expect(SubComment.reflect_on_association(:post)).not_to be_nil
    end

    it "defines association for subclass that has its own associations" do
      expect(OwnComment.reflect_on_association(:post)).not_to be_nil
    end
  end


  context "with abstract base classes" do
    before(:each) do
      create_tables(
        "posts", {}, {}
      )
      stub_model('PostBase') do
        self.abstract_class = true
      end
      stub_model('Post', PostBase)
    end

    it "should skip abstract classes" do
      expect { PostBase.table_name }.to_not raise_error
      expect( PostBase.table_name ).to be_nil
      expect( !! PostBase.table_exists? ).to eq(false)
    end

    it "should work with classes derived from abstract classes" do
      expect( Post.table_name ).to eq("posts")
      expect( !! Post.table_exists? ).to eq(true)
    end
  end

  if defined? ::ActiveRecord::Relation

    context "regarding relations" do
      before(:each) do
        create_tables(
          "posts", {}, {},
          "comments", {}, { post_id: { foreign_key: true} }
        )
        stub_model('Post')
        stub_model('Comment')
      end

      it "should define associations before needed by relation" do
        expect { Post.joins(:comments).to_a }.to_not raise_error
      end
    end
  end

  protected

  def with_associations_auto_create(value, &block)
    with_associations_config(auto_create: value, &block)
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
      ActiveRecord::Base.connection.tables.sort.each do |table|
        ActiveRecord::Migration.drop_table table, force: :cascade
      end
      table_defs.each_slice(3) do |table_name, opts, columns_with_options|
        ActiveRecord::Migration.create_table table_name, **opts do |t|
          columns_with_options.each_pair do |column, options|
            coltype = options.delete(:coltype) || :bigint
            t.send coltype, column, **options
          end
        end
      end
    end
  end

end
