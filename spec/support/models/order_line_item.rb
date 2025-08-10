class OrderLineItem < ActiveRecord::Base
  belongs_to :product
  belongs_to :promo, optional: true

  # has_many :product_categories, through: :product
  # has_many :history_product_categories, through: :product_categories, source: :history, class_name: "HistoryProductCategory"
end
