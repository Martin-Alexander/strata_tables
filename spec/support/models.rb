class ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true

  include StrataTables::Model
end

class Company < ApplicationRecord
  has_many :users
end

class Client < Company
end

class Firm < Company
end

class Team < ApplicationRecord
  has_many :users
end

class Profile < ApplicationRecord
  belongs_to :user
end

class User < ApplicationRecord
  has_one :profile
  belongs_to :team
  belongs_to :company, optional: true, class_name: "Client"
end

class Book < ApplicationRecord
end

class Category < ApplicationRecord
  has_many :products
  has_many :line_items, through: :products
  belongs_to :parent, class_name: "Category"
end

class Product < ApplicationRecord
  belongs_to :category, optional: true
  has_many :category_versions, primary_key: :category_id, foreign_key: :id, class_name: "Category::Version"
  has_many :line_items
  has_many :tags, as: :taggable
end

class Promo < ApplicationRecord
  has_many :line_items
end

class LineItem < ApplicationRecord
  belongs_to :product
  belongs_to :promo, optional: true
end

class Tag < ApplicationRecord
  belongs_to :taggable, polymorphic: true
end
