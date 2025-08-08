class CreateBooks < ActiveRecord::Migration[7.0]
  def change
    create_table(:authors) do |t|
      t.string :name
    end

    create_table(:books) do |t|
      t.string :title, null: false, limit: 100
      t.decimal :price, precision: 10, scale: 2
      t.string :summary, collation: "en_US.utf8"
      t.integer :pages, comment: "Number of pages"
      t.date :published_at, default: "2025-01-01"
      t.references :author, foreign_key: true, index: true
    end
  end
end
