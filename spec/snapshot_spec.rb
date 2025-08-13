require "spec_helper"

RSpec.describe "Snapshot" do
  after do
    DatabaseCleaner.clean_with :truncation
  end

  let(:category) { Category.new(name: "Toys") }
  let(:product) { Product.new(name: "Lego", category: category, price: 100) }
  let(:t1) { get_time }
  let(:t2) { get_time }
  let(:t1_category_snapshot) { category.history.sole.snapshot_at(t1) }
  let(:t2_category_snapshot) { category.history.sole.snapshot_at(t2) }
  let(:t1_product_snapshot) { product.history.sole.snapshot_at(t1) }
  let(:t2_product_snapshot) { product.history.sole.snapshot_at(t2) }

  before do
    category.save!
    t1
    product.save!
    t2
  end

  # describe "::at" do
  #   it "returns snapshots at the given time" do
  #     expect(Product::Snapshot.at(t1).length).to eq(0)

  #     t2_product_snapshots = Product::Snapshot.at(t2)

  #     expect(t2_product_snapshots.length).to eq(1)
  #     expect(t2_product_snapshots.sole)
  #       .to be_a(Product::Snapshot)
  #       .and have_attributes(
  #         id: product.id,
  #         name: "Lego",
  #         price: 100,
  #         category_id: category.id
  #       )
  #   end
  # end
end
