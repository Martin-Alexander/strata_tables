class CreatePromos < ActiveRecord::Migration[7.0]
  def change
    create_table :promos do |t|
      t.string :name, null: false
      t.integer :discount_percentage, null: false
    end
  end
end
