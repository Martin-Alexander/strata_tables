class ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true
end

class User < ApplicationRecord
  has_one :profile
end

class Book < ApplicationRecord
end

class Category < ApplicationRecord
  has_many :products
  has_many :line_items, through: :products
  belongs_to :parent, class_name: "Category"
end

class LineItem < ApplicationRecord
  belongs_to :product
  belongs_to :promo, optional: true
end

class Product < ApplicationRecord
  belongs_to :category, optional: true
  has_many :line_items
  has_many :tags, as: :taggable
end

class Promo < ApplicationRecord
  has_many :line_items
end

class Profile < ApplicationRecord
  belongs_to :user
end

class Tag < ApplicationRecord
  belongs_to :taggable, polymorphic: true
end
