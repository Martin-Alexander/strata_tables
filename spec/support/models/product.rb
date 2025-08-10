class Product < ActiveRecord::Base
  has_many :order_line_items
  belongs_to :product_category

  has_many :history, foreign_key: :id, class_name: "HistoryProduct"

  def self.as_of(time)
    HistoryProduct.as_of(time)
  end

  def as_of(time)
    history.as_of(time).first
  end
end

class HistoryProduct < ActiveRecord::Base
  self.table_name = "strata_products"
  self.primary_key = :hid

  scope :as_of, ->(time) do
    if time.is_a?(Range)
      where("strata_products.validity && ?::timestamp", time)
    else
      where("strata_products.validity @> ?::timestamp", time)
    end
  end

  def temporal_id
    self[:id]
  end

  def ur?
    validity.begin.nil?
  end

  def extant?
    validity.end.nil?
  end

  def extinct?
    validity.end.present?
  end

  belongs_to :temporal, foreign_key: :id, primary_key: :id, class_name: "Product", optional: true
  belongs_to :temporal_product_category, foreign_key: :product_category_id, class_name: "ProductCategory", optional: true
  has_many(
    :product_categories,
    ->(history_product) do
      if history_product.extant?
        where("validity && tsrange(?, NULL)", history_product.validity.begins)
      else
        where("validity && tsrange(?, ?)", history_product.validity.begin, history_product.validity.end)
      end
    end,
    foreign_key: :id,
    primary_key: :product_category_id,
    class_name: "HistoryProductCategory"
  )
  # has_many :history
  has_many :temporal_order_line_items, through: :temporal, source: :order_line_items, class_name: "OrderLineItem"
end
