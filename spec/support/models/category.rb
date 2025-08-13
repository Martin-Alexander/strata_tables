class Category < ApplicationRecord
  has_many :products
  has_many :line_items, through: :products
  belongs_to :parent, class_name: "Category"
end
