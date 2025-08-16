require "spec_helper"

RSpec.describe StrataTables::SnapshotBuilder do
  after do
    DatabaseCleaner.clean_with :truncation
  end

  it "creates an anonymous class that inherits from the original class" do
    klass = snapshot(Product, get_time)

    expect(klass).to be_a(Class)
    expect(klass).to be < Product
    expect(klass.table_name).to eq("strata_products")
  end

  describe "{model}Snapshot" do
    subject { snapshot(Product, t) }

    before do
      subject.load_schema
    end

    let(:t) { get_time }

    product_class_attr_list = "id: integer, name: string, price: integer, category_id: integer, validity: tsrange"
    product_instance_attr_list = "id: nil, name: nil, price: nil, category_id: nil, validity: nil"

    describe "::to_s" do
      it "returns {model.name}Snapshot" do
        expect(subject.to_s).to eq("ProductSnapshot@#{t.iso8601}")
      end
    end

    describe "::inspect" do
      it "returns {model.name}Snapshot({attr_list})" do
        expect(subject.inspect).to eq("ProductSnapshot@#{t.iso8601}(#{product_class_attr_list})")
      end

      context "if the schema is not loaded" do
        before do
          allow(subject).to receive(:schema_loaded?).and_return(false)
        end

        it "returns {model.name}Snapshot@({time})" do
          expect(subject.inspect).to eq("ProductSnapshot@#{t.iso8601}")
        end
      end
    end

    describe "::pretty_print" do
      it "returns {model.name}Snapshot({attr_list})" do
        output = StringIO.new
        PP.pp(subject, output)
        string = output.string.delete("\n")

        expect(string).to eq("ProductSnapshot@#{t.iso8601}(#{product_class_attr_list})")
      end
    end

    describe "#to_s" do
      it "returns #<{model.name}Snapshot{address}>" do
        expect(subject.new.to_s).to match(/^#<ProductSnapshot@#{t.iso8601}:0x[0-9a-f]+>/)
      end
    end

    describe "#inspect" do
      it "returns #<{model.name}Snapshot {attr_list}>" do
        expect(subject.new.inspect).to eq("#<ProductSnapshot@#{t.iso8601} #{product_instance_attr_list}>")
      end
    end

    describe "#pretty_print" do
      it "returns #<{model.name}Snapshot {attr_list}>" do
        output = StringIO.new
        PP.pp(subject.new, output)
        string = output.string.delete("\n")

        expect(string).to eq("#<ProductSnapshot@#{t.iso8601} #{product_instance_attr_list}>")
      end
    end
  end

  describe "querying" do
    let(:team) { Team.create!(name: "Team 1") }
    let(:user) { User.new(first_name: "John", last_name: "Doe", team: team) }
    let(:profile) { Profile.new(user: user, bio: "I am a profile") }
    let(:category) { Category.new(name: "Toys") }
    let(:product) { Product.new(name: "Lego", category: category, price: 100) }
    let(:line_item) { LineItem.new(product: product, quantity: 1) }
    let(:tag) { Tag.new(name: "Lego", taggable: product) }
    let(:t1) { get_time }
    let(:t2) { get_time }
    let(:t3) { get_time }

    before do
      category.save!
      t1
      user.save!
      product.save!
      tag.save!
      t2
      profile.save!
      category.update!(name: "Toys 2")
      product.update!(name: "Lego 2", price: 200)
      line_item.save!
      tag.update!(name: "Lego 2")
      t3
    end

    describe "#readonly?" do
      it "returns true" do
        expect(snapshot(Product, get_time).first.readonly?).to be(true)
      end
    end

    describe "::all" do
      it "returns the snapshots at the given time" do
        expect(snapshot(Product, t1).all).to be_empty
        expect(snapshot(Product, t2).all).not_to be_empty
      end
    end

    describe "::joins" do
      it "works as expected" do
        categories_t1 = snapshot(Category, t1).joins(:products)
        categories_t2 = snapshot(Category, t2).joins(:products)

        expect(categories_t1.count).to eq(0)
        expect(categories_t2.count).to eq(1)
      end
    end

    describe "::eager_load" do
      it "works as expected" do
        categories_t1 = snapshot(Category, t1).eager_load(:products)
        categories_t2 = snapshot(Category, t2).eager_load(:products)

        expect(categories_t1.count).to eq(1)
        expect(categories_t2.count).to eq(1)
        expect(categories_t2.first.products).to be_loaded
      end
    end

    describe "::preload" do
      it "works as expected" do
        categories_t1 = snapshot(Category, t1).preload(:products)
        categories_t2 = snapshot(Category, t2).preload(:products)

        expect(categories_t1.count).to eq(1)
        expect(categories_t2.count).to eq(1)
        expect(categories_t2.first.products).to be_loaded
      end
    end

    describe "has many" do
      it "works as expected" do
        product_t2 = snapshot(Product, t2).first
        product_t3 = snapshot(Product, t3).first

        expect(product_t2.line_items.count).to eq(0)

        expect(product_t3.line_items.count).to eq(1)
        expect(product_t3.line_items.first).to be_a(LineItem)
        expect(product_t3.line_items.first.class).to be < LineItem
        expect(product_t3.line_items.first.product.name).to eq("Lego 2")
      end

      describe "polymorphic" do
        it "works as expected" do
          product_t2 = snapshot(Product, t2).first
          product_t3 = snapshot(Product, t3).first

          expect(product_t2.tags.count).to eq(1)
          expect(product_t2.tags.first).to be_a(Tag)
          expect(product_t2.tags.first.class).to be < Tag
          expect(product_t2.tags.first.name).to eq("Lego")

          expect(product_t3.tags.count).to eq(1)
          expect(product_t3.tags.first.name).to eq("Lego 2")
        end
      end
    end

    describe "belongs to" do
      it "works as expected" do
        product_t2 = snapshot(Product, t2).first
        product_t3 = snapshot(Product, t3).first

        expect(product_t2.category).to be_a(Category)
        expect(product_t2.category.class).to be < Category
        expect(product_t2.category.name).to eq("Toys")
        expect(product_t2.category.products.first.name).to eq("Lego")

        expect(product_t3.category.name).to eq("Toys 2")
        expect(product_t3.category.products.first.name).to eq("Lego 2")
      end

      describe "polymorphic" do
        it "works as expected" do
          tag_t2 = snapshot(Tag, t2).first
          tag_t3 = snapshot(Tag, t3).first

          expect(tag_t2.taggable).to be_a(Product)
          expect(tag_t2.taggable.class).to be < Product
          expect(tag_t2.taggable.name).to eq("Lego")

          expect(tag_t3.taggable.name).to eq("Lego 2")
        end
      end
    end

    describe "has one" do
      it "works as expected" do
        user_t2 = snapshot(User, t2).first
        user_t3 = snapshot(User, t3).first

        expect(user_t2.profile).to be_nil

        expect(user_t3.profile).to be_a(Profile)
        expect(user_t3.profile.class).to be < Profile
        expect(user_t3.profile.bio).to eq("I am a profile")
        expect(user_t3.profile.user).to eq(user_t3)
      end
    end

    describe "has many through" do
      it "works as expected" do
        category_t2 = snapshot(Category, t2).first
        category_t3 = snapshot(Category, t3).first

        expect(category_t2.line_items.count).to eq(0)

        expect(category_t3.line_items.count).to eq(1)
        expect(category_t3.line_items.first).to be_a(LineItem)
        expect(category_t3.line_items.first.class).to be < LineItem
        expect(category_t3.line_items.first.product.name).to eq("Lego 2")
      end

      describe "::joins" do
        it "works as expected" do
          categories_t2 = snapshot(Category, t2).joins(:line_items)
          categories_t3 = snapshot(Category, t3).joins(:line_items)

          expect(categories_t2.count).to eq(0)
          expect(categories_t3.count).to eq(1)
        end
      end

      describe "::eager_load" do
        it "works as expected" do
          categories_t2 = snapshot(Category, t2).eager_load(:line_items)
          categories_t3 = snapshot(Category, t3).eager_load(:line_items)

          expect(categories_t2.count).to eq(1)
          expect(categories_t3.count).to eq(1)
          expect(categories_t3.first.line_items).to be_loaded
        end
      end

      describe "::preload" do
        it "works as expected" do
          categories_t2 = snapshot(Category, t2).preload(:line_items)
          categories_t3 = snapshot(Category, t3).preload(:line_items)

          expect(categories_t2.count).to eq(1)
          expect(categories_t3.count).to eq(1)
          expect(categories_t3.first.line_items).to be_loaded
        end
      end
    end

    context "when a model is not backed by a temporal table" do
      it "works as expected" do
        user_t2 = snapshot(User, t2).first

        expect(user_t2.team.class).to eq(Team)
        expect(user_t2.team.name).to eq("Team 1")

        team_t2 = snapshot(Team, t2).first

        expect(team_t2.users.count).to eq(1)
        expect(team_t2.users.first).to be_a(User)
        expect(team_t2.users.first.class).to be < User
        expect(team_t2.users.first.first_name).to eq("John")
        expect(team_t2.users.first.last_name).to eq("Doe")
      end
    end
  end
end
