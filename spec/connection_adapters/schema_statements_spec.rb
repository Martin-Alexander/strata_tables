require "spec_helper"

RSpec.describe StrataTables::ConnectionAdapters::SchemaStatements do
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
    conn.create_strata_metadata_table
  end

  after do
    conn.tables.each { |table| conn.drop_table(table, force: :cascade) }
  end

  describe "#create_strata_metadata_table" do
    it do
      expect(conn.table(:strata_metadata))
        .to be_present
        .and have_column(:history_table, :string)
        .and have_column(:temporal_table, :string)
        .and have_attributes(primary_key: "history_table")
    end
  end

  describe "#create_history_table_for" do
    it "creates a history table with a default name" do
      conn.enable_extension(:btree_gist)

      conn.create_history_table_for(:books)

      expect(conn).to have_table(:books_history)
      expect(conn.table(:books_history))
        .to be_history_table_for(:books)
        .and have_column(:id, :integer)
        .and have_column(:title, :string, null: false, limit: 100)
        .and have_column(:price, :decimal, precision: 10, scale: 2)
        .and have_column(:summary, :string, collation: "en_US")
        .and have_column(:pages, :integer, comment: "Number of pages")
        .and have_column(:published_at, :date)
        .and have_column(:author_id, :integer)
        .and have_exclusion_constraint("id WITH =, sys_period WITH &&", {using: :gist})
      expect(conn.history_table_for(:books)).to eq("books_history")
    end

    it "creates a history table with a given name" do
      conn.create_history_table_for(:books, :book_history)

      expect(conn.table(:book_history)).to be_history_table_for(:books)
      expect(conn.history_table_for(:books)).to eq("book_history")
    end

    it "skips the exclusion constraint if btree_gist is not enabled" do
      conn.create_history_table_for(:books)

      expect(conn.table(:books_history)).to_not have_exclusion_constraint
    end

    it "skips columns includedsx in 'except'" do
      conn.create_history_table_for(:books, except: [:title, :price, :summary])

      table = conn.table(:books_history)

      expect(table).to be_history_table_for(:books)
      expect(table)
        .to not_have_column(:title)
        .and not_have_column(:price)
        .and not_have_column(:summary)
        .and have_column(:id)
        .and have_column(:pages)
        .and have_column(:published_at)
        .and have_column(:author_id)
    end

    it "raises an error when source table does not exist" do
      expect { conn.create_history_table_for(:teddies) }
        .to raise_error(ActiveRecord::StatementInvalid, /relation "teddies" does not exist/)
    end

    describe "with copy_data option" do
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

        conn.create_history_table_for(:authors)
        conn.create_history_table_for(:books, copy_data: true)

        expect(Author.version.count).to eq(0)
        expect(Book.version.count).to eq(2)
        expect(Book.version.all.as_of(t_0).count).to eq(2)
        expect(Book.version.all.as_of(now).count).to eq(2)
      end

      it "sets sys_period when epoch is provided" do
        epoch_time = Time.parse("1999-01-01")

        conn.enable_extension(:btree_gist)

        conn.create_history_table_for(:authors)
        conn.create_history_table_for(:books, copy_data: {epoch_time: epoch_time})

        expect(Author.version.count).to eq(0)
        expect(Book.version.count).to eq(2)
        expect(Book.version.all.as_of(t_1).count).to eq(2)
        expect(Book.version.all.as_of(now).count).to eq(2)
        expect(Book.version.all.as_of(epoch_time - 1.day).count).to eq(0)
      end
    end
  end

  describe "#drop_history_table_for" do
    it "drops the temporal table's history table" do
      conn.create_history_table_for(:books)

      conn.drop_history_table_for(:books)

      history_table = conn.table(:books_history)
      original_table = conn.table(:books)

      expect(history_table).to be_nil
      expect(original_table).to be_present

      expect(original_table)
        .to not_have_trigger(:on_insert_strata_trigger)
        .and not_have_trigger(:on_update_strata_trigger)
        .and not_have_trigger(:on_delete_strata_trigger)

      expect(conn)
        .to not_have_function(:books_history_insert)
        .and not_have_function(:books_history_update)
        .and not_have_function(:books_history_delete)

      expect(conn.history_table_for(:books)).to be_nil
    end

    it "drops the temporal table's history table with a given name" do
      conn.create_history_table_for(:books, :book_history)

      conn.drop_history_table_for(:books)

      history_table = conn.table(:book_history)
      original_table = conn.table(:books)

      expect(history_table).to be_nil
      expect(original_table).to be_present
      expect(conn.history_table_for(:books)).to be_nil
    end
  end

  describe "#history_table_for" do
    it "returns the history table" do
      conn.create_history_table_for(:authors)
      conn.create_history_table_for(:books, :book_history)

      expect(conn.history_table_for(:authors)).to eq("authors_history")
      expect(conn.history_table_for(:books)).to eq("book_history")
      expect(conn.history_table_for(:teddies)).to be_nil
    end

    it "returns the history table with spaces or schema qualified" do
      skip

      conn.create_history_table_for(:authors, "history.authors_history")
      conn.create_history_table_for(:books, "Book History")

      expect(conn.history_table_for(:authors)).to eq("history.authors_history")
      expect(conn.history_table_for(:books)).to eq("History")
    end
  end

  describe "#temporal_table_for" do
    it "#returns the temporal table" do
      conn.create_history_table_for(:authors)
      conn.create_history_table_for(:books, :book_history)

      expect(conn.temporal_table_for(:authors_history)).to eq("authors")
      expect(conn.temporal_table_for(:book_history)).to eq("books")
      expect(conn.temporal_table_for(:teddies_history)).to be_nil
    end

    it "returns the temporal table with spaces or schema qualified" do
      skip

      conn.create_history_table_for(:authors, "history.authors_history")
      conn.create_history_table_for(:books, "Book History")

      expect(conn.temporal_table_for("history.authors_history")).to eq("authors")
      expect(conn.temporal_table_for("Book History")).to eq("books")
    end
  end
end
