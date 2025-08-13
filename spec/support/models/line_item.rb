class LineItem < ApplicationRecord
  belongs_to :product
  belongs_to :promo, optional: true
end
