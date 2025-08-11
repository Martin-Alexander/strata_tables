class Promo < ActiveRecord::Base
  has_many :line_items
end

class Promo::Version < Promo
  self.table_name = "strata_promos"
  self.primary_key = :hid

  has_many :line_item_versions, primary_key: :id, foreign_key: :promo_id, class_name: "LineItem::Version"

  def line_items_at(time)
    raise ArgumentError, "outside the validity range" unless validity.cover?(time)

    line_item_versions.where("validity @> ?::timestamp", time)
  end
end
