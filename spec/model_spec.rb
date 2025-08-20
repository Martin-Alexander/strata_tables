require "spec_helper"

RSpec.describe StrataTables::Model do
  after do
    DatabaseCleaner.clean_with :truncation
  end

  before do
    t0

    team.save!
    user.save!
    category.save!
    product.save!
    tag.save!

    t1

    product.update!(name: "Lego 2", price: 200, category: category)

    t2
  end

  let(:team) { Team.new(name: "Team 1") }
  let(:client) { Client.new(name: "Client 1") }
  let(:user) { User.new(first_name: "John", last_name: "Doe", team: team, company: client) }
  let(:category) { Category.new(name: "Toys") }
  let(:product) { Product.new(name: "Lego", price: 100, category: category) }
  let(:tag) { Tag.new(name: "Lego", taggable: product) }

  let(:product_version) { Product::Version.first }
  let(:user_version) { User::Version.first }
  let(:tag_version) { Tag::Version.first }
  let(:user_version) { User::Version.first }
  let(:client_version) { Client::Version.first }

  let(:t0) { get_time }
  let(:t1) { get_time }
  let(:t2) { get_time }

  describe "::Version" do
    it "returns a subclass of the original model" do
      expect(Product::Version).to be < Product
    end

    it "has a table name of the original model with _versions" do
      expect(Product::Version.table_name).to eq("products_versions")
    end

    context "one a model that is not backed by a strata table" do
      it "returns a subclass of the original model" do
        expect(Team::Version).to be < Team
      end

      it "keeps its original table name" do
        expect(Team::Version.table_name).to eq("teams")
      end
    end
  end

  describe "::versions" do
    it "returns all versions" do
      expect(Product.versions.count).to eq(2)
      expect(Product.versions.first.name).to eq("Lego 2")
      expect(Product.versions.last.name).to eq("Lego")
    end
  end

  describe "#version" do
    it "returns the first version" do
      expect(Product.first.version).to be_a(Product::Version)
      expect(Product.first.version).to have_attributes(
        name: "Lego 2",
        price: 200,
        category_id: category.id
      )
    end
  end

  describe "as-of scoping" do
    it "scopes all queries to the given validity" do
      product_version = as_of_scope(t1) do
        Product::Version.first
      end

      expect(product_version.name).to eq("Lego")

      product_version = as_of_scope(t0) do
        Product::Version.first
      end

      expect(product_version).to be_nil
    end
  end

  describe "default scope" do
    it "orders by validity" do
      expect(Product::Version.all.count).to eq(2)
      expect(Product::Version.all.first.name).to eq("Lego 2")
      expect(Product::Version.all.last.name).to eq("Lego")
    end
  end

  describe "associations" do
    it "returns versions of the associated model" do
      expect(product_version.category).to be_a(Category::Version)
    end

    context "when the associated model is not backed by a strata table" do
      it "returns the version" do
        expect(user_version.team).to be_a(Team::Version)
      end
    end

    context "when the base model has an association with a versioned model" do
      it "returns the version" do
        expect(product.category_versions.first).to be_a(Category::Version)
        expect(product_version.category_versions.first).to be_a(Category::Version)
      end
    end

    describe "polymorphic associations" do
      it "returns versions" do
        expect(tag_version.taggable).to be_a(Product::Version)
        expect(product_version.tags.first).to be_a(Tag::Version)
      end
    end

    describe "sti associations" do
      it "returns versions" do
        expect(user_version.company).to be_a(Client::Version)
        expect(client_version.users.first).to be_a(User::Version)
      end
    end
  end

  describe "joins" do
    it "works as expected" do
      new_product = Product.create!(name: "Lego 3", price: 300, category: nil)

      expect(Product::Version.select(:id).joins(:category)).not_to include(new_product.id)
    end
  end

  describe "eager loading" do
    it "works as expected" do
      expect(Product::Version.preload(:category).first.category).to be_a(Category::Version)
      expect(Product::Version.eager_load(:category).first.category).to be_a(Category::Version)
    end
  end
end
