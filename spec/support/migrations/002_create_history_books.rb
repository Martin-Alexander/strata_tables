class CreateStrataBooks < ActiveRecord::Migration[7.0]
  def change
    create_table :strata_books, primary_key: :hid do |t|
      t.integer :id, null: false
      t.string :title
      t.integer :pages
      t.date :published_at
      t.tsrange :validity, null: false
    end
  end
end
