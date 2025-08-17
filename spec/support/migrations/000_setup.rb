class Setup < ActiveRecord::Migration[8.0]
  def change
    create_table :companies do |t|
      t.string :name, null: false
      t.string :type, null: false
    end

    create_strata_table :companies

    create_table :teams do |t|
      t.string :name, null: false
    end

    create_table :users do |t|
      t.string :first_name, null: false
      t.string :last_name, null: false
      t.references :team, foreign_key: true, index: true
      t.references :company, foreign_key: true, index: true
    end

    create_strata_table :users

    create_table :categories do |t|
      t.string :name, null: false
      t.references :parent, foreign_key: {to_table: :categories}
    end

    create_strata_table :categories

    create_table :products do |t|
      t.string :name, null: false
      t.integer :price, null: false
      t.references :category, foreign_key: true, index: true
    end

    create_strata_table :products

    create_table :promos do |t|
      t.string :name, null: false
      t.integer :discount_percentage, null: false
    end

    create_table :line_items do |t|
      t.references :product, foreign_key: true, index: true, null: false
      t.references :promo, foreign_key: true, index: true
      t.integer :quantity, null: false
      t.timestamps
    end

    create_strata_table :line_items

    create_table :profiles do |t|
      t.references :user, foreign_key: true, index: true
      t.string :bio
    end

    create_strata_table :profiles

    create_table :tags do |t|
      t.string :name, null: false
      t.references :taggable, polymorphic: true, null: false
    end

    create_strata_table :tags

    create_table :authors do |t|
      t.string :name
    end

    create_table :books do |t|
      t.string :title, null: false, limit: 100
      t.decimal :price, precision: 10, scale: 2
      t.string :summary, collation: "en_US.utf8"
      t.integer :pages, comment: "Number of pages"
      t.date :published_at, default: "2025-01-01"
      t.references :author, foreign_key: true, index: true
    end
  end
end
