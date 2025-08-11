class Category < ActiveRecord::Base
  has_many :products
  has_many :line_items, through: :products
  belongs_to :parent, class_name: "Category"
end

class Category::Version < Category
  self.table_name = "strata_categories"
  self.primary_key = :hid

  has_many :product_versions, primary_key: :id, foreign_key: :category_id, class_name: "Product::Version"
  has_many :line_item_versions, primary_key: :id, foreign_key: :category_id, class_name: "LineItem::Version"
  has_many :parent_versions, primary_key: :parent_id, foreign_key: :id, class_name: "Category::Version"

  def products_at(time)
    raise ArgumentError, "outside the validity range" unless validity.cover?(time)

    product_versions.where("validity @> ?::timestamp", time)
  end

  def line_items_at(time)
    raise ArgumentError, "outside the validity range" unless validity.cover?(time)

    line_item_versions.where("validity @> ?::timestamp", time)
  end

  def parent_at(time)
    raise ArgumentError, "outside the validity range" unless validity.cover?(time)

    parent_versions.find_by("validity @> ?::timestamp", time)
  end
end
