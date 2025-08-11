class CreateProducts < ActiveRecord::Migration[8.0]
  def change
    create_table :products do |t|
      t.string :name, null: false
      t.integer :price, null: false
      t.references :category, foreign_key: true, index: true
    end

    create_strata_table :products
  end
end
