class CreateProductCategories < ActiveRecord::Migration[8.0]
  def change
    create_table(:product_categories) do |t|
      t.string :name, null: false
    end

    create_strata_table(:product_categories)

    add_reference :products, :product_category, foreign_key: true, index: true
    add_strata_column :products, :product_category_id, :integer
  end
end
