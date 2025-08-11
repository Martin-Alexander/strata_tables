class CreateLineItems < ActiveRecord::Migration[7.0]
  def change
    create_table :line_items do |t|
      t.references :product, foreign_key: true, index: true, null: false
      t.references :promo, foreign_key: true, index: true
      t.integer :quantity, null: false
      t.timestamps
    end

    create_strata_table :line_items
  end
end
