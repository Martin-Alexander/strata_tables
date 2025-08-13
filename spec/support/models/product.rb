class Product < ApplicationRecord
  belongs_to :category, optional: true
  has_many :line_items
end
