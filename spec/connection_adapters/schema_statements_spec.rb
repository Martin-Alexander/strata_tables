require "spec_helper"

RSpec.describe StrataTables::ConnectionAdapters::SchemaStatements do
  shared_context "with a history table setup for books" do
    before { conn.create_history_table(:books) }
  end

  before do
    conn.create_table :authors do |t|
      t.string :name
    end
    conn.create_table :books do |t|
      t.string :title, null: false, limit: 100
      t.decimal :price, precision: 10, scale: 2
      t.string :summary, collation: "en_US"
      t.integer :pages, comment: "Number of pages"
      t.date :published_at, default: "2025-01-01"
      t.references :author, foreign_key: true, index: true
    end
  end

  after do
    conn.drop_table(:books) if conn.table_exists?(:books)
    conn.drop_table(:authors) if conn.table_exists?(:authors)
    conn.drop_table(:teddies) if conn.table_exists?(:teddies)

    conn.drop_table(:books__history) if conn.table_exists?(:books__history)
    conn.drop_table(:authors__history) if conn.table_exists?(:authors__history)
  end

  describe "#create_history_table" do
    it "creates a history table" do
      conn.enable_extension(:btree_gist)

      conn.create_history_table(:books)

      expect(conn).to have_table(:books__history)

      expect(:books).to have_history_table

      expect(:books__history)
        .to have_column(:id, :integer)
        .and have_column(:title, :string, null: false, limit: 100)
        .and have_column(:price, :decimal, precision: 10, scale: 2)
        .and have_column(:summary, :string, collation: "en_US")
        .and have_column(:pages, :integer, comment: "Number of pages")
        # TODO: support old and new version of the `#column_exists?` method
        # .and have_column(:published_at, :date, default: Date.new(2025, 1, 1))
        .and have_column(:published_at, :date)
        .and have_column(:author_id, :integer)

      expect(:books__history).to have_exclusion_constraint(
        "id WITH =, validity WITH &&",
        {using: :gist}
      )
    end

    context "when btree_gist extension is not enabled" do
      it "does not crate a temporal exclusion constraint" do
        conn.disable_extension(:btree_gist)

        conn.create_history_table(:books)

        expect(:books).to have_history_table

        expect(:books__history).to_not have_exclusion_constraint(
          "id WITH =, validity WITH &&",
          {using: :gist}
        )
      end
    end

    context "with 'except'" do
      it "omits columns from the history table" do
        conn.create_history_table(:books, except: [:title, :price, :summary])

        expect(conn).to have_table(:books__history)

        expect(:books).to have_history_table

        expect(:books__history)
          .to not_have_column(:title)
          .and(not_have_column(:price))
          .and(not_have_column(:summary))
          .and(have_column(:id))
          .and(have_column(:pages))
          .and(have_column(:published_at))
          .and(have_column(:author_id))
      end
    end

    context "with 'copy_data'" do
      before do
        stub_const("ApplicationRecord", Class.new(ActiveRecord::Base) do
          self.abstract_class = true
          include StrataTables::Model
        end)
        stub_const("Author", Class.new(ApplicationRecord))
        stub_const("Book", Class.new(ApplicationRecord))

        bob = Author.create!(name: "Bob")

        Book.create!(title: "Calliou", price: 1000, pages: 10, author_id: bob.id)
        Book.create!(title: "Calliou 2", price: 500, pages: 10, author_id: bob.id)

        t_0
      end

      it "copies data" do
        conn.enable_extension(:btree_gist)

        conn.create_history_table(:authors)
        conn.create_history_table(:books, copy_data: true)

        expect(Author.version.count).to eq(0)
        expect(Book.version.count).to eq(2)
        expect(Book.version.all.as_of(t_0).count).to eq(2)
        expect(Book.version.all.as_of(now).count).to eq(2)
      end

      context "with epoch year" do
        it "start validity ranges at epoch year" do
          epoch_time = Time.parse("1999-01-01")

          conn.enable_extension(:btree_gist)

          conn.create_history_table(:authors)
          conn.create_history_table(:books, copy_data: {epoch_time: epoch_time})

          expect(Author.version.count).to eq(0)
          expect(Book.version.count).to eq(2)
          expect(Book.version.all.as_of(t_1).count).to eq(2)
          expect(Book.version.all.as_of(now).count).to eq(2)
          expect(Book.version.all.as_of(epoch_time - 1.day).count).to eq(0)
        end
      end
    end

    context "when source table does not exist" do
      it "raises an error" do
        expect { conn.create_history_table(:teddies) }
          .to raise_error(ActiveRecord::StatementInvalid, /relation "teddies" does not exist/)
      end
    end
  end

  describe "#drop_history_table" do
    include_context "with a history table setup for books"

    it "drops a history table" do
      conn.drop_history_table(:books)

      expect(conn).to have_table(:books)

      expect(conn).not_to have_table(:books__history)

      expect(:books)
        .to not_have_trigger(:on_insert_strata_trigger)
        .and not_have_trigger(:on_update_strata_trigger)
        .and not_have_trigger(:on_delete_strata_trigger)

      expect(conn)
        .to not_have_function(:books_history_insert)
        .and not_have_function(:books_history_update)
        .and not_have_function(:books_history_delete)
    end
  end
end
