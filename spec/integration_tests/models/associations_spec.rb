require "spec_helper"

# class Timeline
#   def initialize
#     @events = {}
#   end

#   def method_missing(method, *args, &block)
#     return super unless args.length.zero?

#     return @events[method] if @events.key?(method)

#     @events[method] ||= Time.now

#     sleep 0.1

#     @events[method]
#   end

#   def respond_to_missing?(method, include_private = false)
#     super
#   end
# end

RSpec.describe "associations" do
  after do
    DatabaseCleaner.clean_with :truncation
  end

  let(:kids_category) { ProductCategory.new(name: "Kids") }
  let(:kids_toys_category) { ProductCategory.new(name: "Kids Toys") }
  let(:jenga) { Product.new(name: "Jenga", price: 100) }
  let(:lego) { Product.new(name: "Lego", price: 300) }
  let(:order_line_item) { OrderLineItem.new(quantity: 1) }

  # before do
  #   kids_category
  #   jenga
  #   order_line_item
  #   jenga.update(price: 200)
  #   jenga.update(price: 250)
  #   kids_toys_category
  #   jenga.update(product_category: kids_toys_category)
  #   kids_category.destroy
  #   lego
  # end

  # it do
  # end

  # describe "temporal has_many :history_{relation}" do
  #   it "returns history records" do
  #     expect(order_line_item.history_products.count).to eq(4)
  #     expect(order_line_item.history_products)
  #       .to all(be_a(HistoryProduct).and(have_attributes(temporal_id: jenga.id)))

  #     expect(jenga.history_product_categories.count).to eq(2)
  #     expect(jenga.history_product_categories)
  #       .to all(be_a(HistoryProductCategory))
  #       .and include(have_attributes(temporal_id: kids_category.id), have_attributes(temporal_id: kids_toys_category.id))
  #   end
  # end

  describe "temporal has_many :history" do
    before do
      kids_category.save

      jenga.product_category = kids_category
      jenga.save

      jenga.update(price: 200)
      jenga.update(price: 250)

      kids_toys_category.save

      jenga.update(product_category: kids_toys_category)
    end

    it "returns history records" do
      expect(jenga.history.count).to eq(4)
      expect(jenga.history)
        .to all(be_a(HistoryProduct).and(have_attributes(temporal_id: jenga.id)))
        .and include(have_attributes(product_category_id: kids_category.id)).exactly(3).times
        .and include(have_attributes(product_category_id: kids_toys_category.id)).exactly(1).times
    end
  end

  describe "history belongs_to :{temporal_rel}" do
    before do
      kids_category.save

      jenga.product_category = kids_category
      jenga.save

      kids_toys_category.save

      jenga.update(product_category: kids_toys_category)

      kids_category.destroy
    end

    it "returns the temporal record" do
      expect(jenga.history.count).to eq(2)

      first_jenga_history = jenga.history.order(:validity).first
      second_jenga_history = jenga.history.order(:validity).last

      expect(first_jenga_history.product_category).to be_nil
      expect(second_jenga_history.product_category).to eq(kids_toys_category)
    end
  end

  describe "history has_many :{temporal_rel}s" do
    before do
      kids_toys_category.save

      jenga.product_category = kids_toys_category
      jenga.save

      kids_toys_category.update(name: "Kid's Toys")

      lego.product_category = kids_toys_category
      lego.save

      kids_toys_category.update(name: "Toys of Kids")
    end

    it "returns the temporal records" do
      last_history_category = kids_toys_category.history.order(:validity).last

      expect(last_history_category.products.count).to eq(2)
      expect(last_history_category.products).to include(jenga, lego)

      second_to_last_history_category = kids_toys_category.history.order(:validity).second_to_last

      expect(second_to_last_history_category.products.count).to eq(1)
      expect(second_to_last_history_category.products).to include(jenga)
    end
  end

  describe "history has_many :{rel}s" do
    before do
      kids_category.save

      jenga.product_category = kids_category
      jenga.save

      order_line_item.product = jenga
      order_line_item.save

      kids_toys_category.save

      jenga.update(product_category: kids_toys_category)

      kids_toys_category.update(name: "Kid's Toys")
    end

    it "returns the records" do
      last_product_history = jenga.history.order(:validity).last

      expect(last_product_history.order_line_items.count).to eq(1)
      expect(last_product_history.order_line_items).to include(order_line_item)
    end
  end

  describe ".as_of" do
    before do
      # Create two history records for the product category
      kids_toys_category.save
      kids_toys_category.update(name: "Kid's Toys")

      # Create two history records for the product
      jenga.product_category = kids_toys_category
      jenga.save

      jenga.update(price: 200)

      OrderLineItem.create(product: jenga, quantity: 1)

      order_line_item.product = jenga
      order_line_item.save

      kids_toys_category.update(name: "Toys of Kids")
    end

    it do
      product_category = ProductCategory
        .joins(history: {history_products: {temporal: :order_line_items}})
        .where(order_line_items: {id: order_line_item.id})
        .merge(HistoryProduct.as_of(order_line_item.created_at))
        .merge(HistoryProductCategory.as_of(order_line_item.created_at))
        .sole

      expect(product_category)
        .to be_a(ProductCategory)
        .and have_attributes(name: "Toys of Kids")

      history_product_category = HistoryProductCategory
        .joins(history_products: {temporal: :order_line_items})
        .where(order_line_items: {id: order_line_item.id})
        .merge(HistoryProduct.as_of(order_line_item.created_at))
        .merge(HistoryProductCategory.as_of(order_line_item.created_at))
        .sole

      expect(history_product_category)
        .to be_a(HistoryProductCategory)
        .and have_attributes(
          name: "Kid's Toys",
          validity: cover(order_line_item.created_at)
        )

      debugger

      # product_category = ProductCategory
      #   .joins(:order_line_items)
      #   .as_of(order_line_item.created_at)
      #   .where(order_line_items: order_line_item)
      #   .sole

      # p product_category

      # product_category = order_line_item
      #   .as_of(order_line_item.created_at)
      #   .product_category

      # p product_category

      # def deep_keys_and_values(obj)

      # end

      # rel = HistoryProductCategory
      #   .joins(history_products: :order_line_items)
      #   .where(order_line_items: {id: order_line_item.id})
      #   .merge(HistoryProduct.as_of(order_line_item.created_at))
      #   .merge(HistoryProductCategory.as_of(order_line_item.created_at))

      # debugger
    end
  end

  # describe "history has_many :history_{N:1}s" do
  #   before do
  #     kids_category.save

  #     jenga.product_category = kids_category
  #     jenga.save

  #     kids_toys_category.save

  #     jenga.update(product_category: kids_toys_category)

  #     kids_toys_category.update(name: "Kid's Toys")

  #     kids_category.destroy
  #   end

  #   it "returns the history records" do
  #     expect(jenga.history.count).to eq(2)

  #     first_jenga_history = jenga.history.first
  #     second_jenga_history = jenga.history.last

  #     expect(first_jenga_history.history_product_categories.count).to eq(1)
  #     expect(first_jenga_history.history_product_categories)
  #       .to all(
  #         be_a(HistoryProductCategory)
  #           .and(be_extinct)
  #           .and(have_attributes(temporal_id: kids_category.id))
  #       )

  #     expect(second_jenga_history.history_product_categories.count).to eq(2)
  #     expect(second_jenga_history.history_product_categories)
  #       .to all(be_a(HistoryProductCategory).and(have_attributes(temporal_id: kids_toys_category.id)))
  #       .and include(have_attributes(name: "Kids Toys").and(be_extinct)).once
  #       .and include(have_attributes(name: "Kid's Toys").and(be_extant)).once
  #   end
  # end

  # describe "history has_many :history_{N:N}" do
  #   before do
  #     kids_category.save
  #     kids_toys_category.save

  #     jenga.product_category = kids_category
  #     jenga.save

  #     jenga.update(price: 200)

  #     jenga.update(product_category: kids_toys_category)
  #   end

  #   it "returns the history records" do
  #     history_kids_category = kids_category.history.first

  #     expect(history_kids_category.history_products.count).to eq(2)
  #     expect(history_kids_category.history_products)
  #       .to all(be_a(HistoryProduct).and(have_attributes(temporal_id: jenga.id)))
  #       .and include(have_attributes(price: 100).and(be_extinct)).once
  #       .and include(have_attributes(price: 200).and(be_extinct)).once
  #   end
  # end
end
