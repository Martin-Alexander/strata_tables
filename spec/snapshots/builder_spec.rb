require "spec_helper"

RSpec.describe StrataTables::Snapshots::Builder do
  subject { described_class }

  after do
    DatabaseCleaner.clean_with :truncation
  end

  it "creates an anonymous snapshot class that inherits from the original class" do
    klass = subject.build(Product, get_time)

    expect(klass).to be_a(Class)
    expect(klass).to be < Product
    expect(klass.table_name).to eq("strata_products")
  end

  context "when given an ActiveRecord instance" do
    let(:category) { Category.new(name: "Toys") }
    let(:t) { get_time }

    before do
      category.save!
      t
    end

    it "creates a snapshot instance" do
      category_snapshot = subject.build(category, t)

      expect(category_snapshot).to be_a(Category)
      expect(category_snapshot).to have_attributes(
        name: "Toys",
        parent: nil,
        validity: be_present
      )
      expect(category_snapshot.class.snapshot_time).to eq(t)
    end
  end

  context "when given a relation" do
    let(:category) { Category.new(name: "Toys") }
    let(:t) { get_time }

    before do
      category.save!
      t
    end

    it "creates a snapshot relation" do
      categories_snapshot = subject.build(Category.all, t)

      expect(categories_snapshot).to be_a(ActiveRecord::Relation)
      expect(categories_snapshot.count).to eq(1)
      expect(categories_snapshot.first).to have_attributes(
        name: "Toys",
        parent: nil,
        validity: be_present
      )
      expect(categories_snapshot.first.class.snapshot_time).to eq(t)
    end
  end
end
