class LineItem < ActiveRecord::Base
  belongs_to :product
  belongs_to :promo, optional: true
end

class LineItem::Version < LineItem
  self.table_name = "strata_line_items"
  self.primary_key = :hid

  has_many :product_versions, primary_key: :product_id, foreign_key: :id, class_name: "Product::Version"
  has_many :promo_versions, primary_key: :promo_id, foreign_key: :id, class_name: "Promo::Version"

  def product_at(time)
    raise ArgumentError, "outside the validity range" unless validity.cover?(time)

    product_versions.find_by("validity @> ?::timestamp", time)
  end

  def promo_at(time)
    raise ArgumentError, "outside the validity range" unless validity.cover?(time)

    promo_versions.find_by("validity @> ?::timestamp", time)
  end
end
