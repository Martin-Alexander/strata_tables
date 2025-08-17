require "spec_helper"

RSpec.describe StrataTables::Snapshot do
  after do
    DatabaseCleaner.clean_with :truncation
  end

  let(:team) { Team.create!(name: "Team 1") }
  let(:client) { Client.new(name: "Client 1", type: "Client") }
  let(:user) { User.new(first_name: "John", last_name: "Doe", team: team, company: client) }
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
    client.save!

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

    it "raises an error when trying to save" do
      expect { snapshot(Product, get_time).first.save! }.to raise_error(ActiveRecord::ReadOnlyRecord)
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
      expect(product_t3.line_items.first.class).to be < LineItem
      expect(product_t3.line_items.first.product.name).to eq("Lego 2")
    end

    describe "polymorphic" do
      it "works as expected" do
        product_t2 = snapshot(Product, t2).first
        product_t3 = snapshot(Product, t3).first

        expect(product_t2.tags.count).to eq(1)
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
    it "is timeless" do
      teams_t3 = snapshot(Team, t3)
      teams_early = snapshot(Team, 100.years.ago)
      teams_late = snapshot(Team, 100.years.from_now)

      expect(teams_t3.count).to eq(1)
      expect(teams_t3.first.name).to eq("Team 1")

      expect(teams_early.count).to eq(1)
      expect(teams_early.first.name).to eq("Team 1")

      expect(teams_late.count).to eq(1)
      expect(teams_late.first.name).to eq("Team 1")
    end

    it "has temporal associations" do
      users_t2 = snapshot(User, t2)
      teams_t3 = snapshot(Team, t3)
      teams_early = snapshot(Team, 100.years.ago)
      teams_late = snapshot(Team, 100.years.from_now)

      expect(users_t2.first.team.class).to be < Team
      expect(users_t2.first.team.name).to eq("Team 1")

      expect(teams_early.first.users.count).to eq(0)

      expect(teams_t3.first.users.count).to eq(1)
      expect(teams_t3.first.users.first.class).to be < User
      expect(teams_t3.first.users.first.first_name).to eq("John")
      expect(teams_t3.first.users.first.last_name).to eq("Doe")

      expect(teams_late.first.users.count).to eq(1)
    end
  end

  describe "single table inheritance" do
    it "works as expected" do
      client_t1 = snapshot(Client, t1).first
      user_t2 = snapshot(User, t2).first

      expect(client_t1.class).to be < Client
      expect(client_t1.name).to eq("Client 1")
      expect(client_t1.users).to be_empty

      expect(user_t2.company.class).to be < Client
      expect(user_t2.company.name).to eq("Client 1")
      expect(user_t2.company.users.count).to eq(1)

      expect(user_t2.company.users.first.class).to be < User
    end
  end
end
