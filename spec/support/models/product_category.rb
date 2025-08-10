class ProductCategory < ActiveRecord::Base
  has_many :products
  has_many :order_line_items, through: :products

  has_many :history, foreign_key: :id, class_name: "HistoryProductCategory"
end

class HistoryProductCategory < ProductCategory
  self.table_name = "strata_product_categories"
  self.primary_key = :hid

  scope :as_of, ->(time) do
    if time.is_a?(Range)
      where("strata_product_categories.validity && ?::timestamp", time)
    else
      where("strata_product_categories.validity @> ?::timestamp", time)
    end
  end

  def temporal_id
    self[:id]
  end

  def ur?
    validity.first.nil?
  end

  def extant?
    validity.end.nil?
  end

  def extinct?
    validity.end.present?
  end

  belongs_to :temporal, foreign_key: :id, primary_key: :id, class_name: "ProductCategory"
  has_many(
    :contemporaneous_products,
    ->(history_product_category) { where("? && strata_products.validity", history_product_category.validity) },
    foreign_key: :product_category_id,
    primary_key: :id,
    class_name: "HistoryProduct"
  )
  has_many :history_products, foreign_key: :product_category_id, primary_key: :id
  has_many :temporal_products, through: :history_products, source: :temporal, class_name: "Product"
  has_many :temporal_order_line_items, through: :temporal_products, source: :order_line_items, class_name: "OrderLineItem"
end
