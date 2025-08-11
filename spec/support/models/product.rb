class Product < ActiveRecord::Base
  belongs_to :category, optional: true
  has_many :line_items
end

class Product::Version < Product
  self.table_name = "strata_products"
  self.primary_key = :hid

  has_many :category_versions, primary_key: :category_id, foreign_key: :id, class_name: "Category::Version"
  has_many :line_item_versions, primary_key: :id, foreign_key: :product_id, class_name: "LineItem::Version"

  def category_at(time)
    raise ArgumentError, "outside the validity range" unless validity.cover?(time)

    category_versions.find_by("validity @> ?::timestamp", time)
  end

  def line_items_at(time)
    raise ArgumentError, "outside the validity range" unless validity.cover?(time)

    line_item_versions.where("validity @> ?::timestamp", time)
  end
end
