require "spec_helper"

RSpec.describe StrataTables::ConnectionAdapters::SchemaStatements do
  shared_context "with a temporal table setup for books" do
    before { conn.create_temporal_table(:books) }
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

    conn.drop_table(:books_versions) if conn.table_exists?(:books_versions)
    conn.drop_table(:authors_versions) if conn.table_exists?(:authors_versions)
  end

  describe "#create_temporal_table" do
    it "creates a temporal table" do
      conn.create_temporal_table(:books)

      expect(conn).to have_table(:books_versions)

      expect(:books).to have_temporal_table

      expect(:books_versions)
        .to have_column(:id, :integer)
        .and have_column(:title, :string, null: false, limit: 100)
        .and have_column(:price, :decimal, precision: 10, scale: 2)
        .and have_column(:summary, :string, collation: "en_US")
        .and have_column(:pages, :integer, comment: "Number of pages")
        # TODO: support old and new version of the `#column_exists?` method
        # .and have_column(:published_at, :date, default: Date.new(2025, 1, 1))
        .and have_column(:published_at, :date)
        .and have_column(:author_id, :integer)
    end

    context "with 'except'" do
      it "omits columns from the history table" do
        conn.create_temporal_table(:books, except: [:title, :price, :summary])

        expect(conn).to have_table(:books_versions)

        expect(:books).to have_temporal_table

        expect(:books_versions)
          .to not_have_column(:title)
          .and(not_have_column(:price))
          .and(not_have_column(:summary))
          .and(have_column(:id))
          .and(have_column(:pages))
          .and(have_column(:published_at))
          .and(have_column(:author_id))
      end
    end

    context "when source table does not exist" do
      it "raises an error" do
        expect { conn.create_temporal_table(:teddies) }
          .to raise_error(ActiveRecord::StatementInvalid, /relation "teddies" does not exist/)
      end
    end
  end

  describe "#drop_temporal_table" do
    include_context "with a temporal table setup for books"

    it "drops a temporal table" do
      conn.drop_temporal_table(:books)

      expect(conn).to have_table(:books)

      expect(conn).not_to have_table(:books_versions)

      expect(:books)
        .to not_have_trigger(:on_insert_strata_trigger)
        .and not_have_trigger(:on_update_strata_trigger)
        .and not_have_trigger(:on_delete_strata_trigger)

      expect(conn)
        .to not_have_function(:books_versions_insert)
        .and not_have_function(:books_versions_update)
        .and not_have_function(:books_versions_delete)
    end
  end

  describe "#add_temporal_column" do
    include_context "with a temporal table setup for books"

    it "adds a temporal column" do
      conn.add_temporal_column(:books, :subtitle, :string)

      expect(:books_versions).to have_column(:subtitle, :string)
    end

    context "when source table does not exist" do
      it "raises an error" do
        expect { conn.add_temporal_column(:teddies, :author_id, :integer) }
          .to raise_error(ActiveRecord::StatementInvalid, /relation "teddies_versions" does not exist/)
      end
    end

    context "when temporal table does not exist" do
      before { conn.create_table(:teddies) }

      it "raises an error" do
        expect { conn.add_temporal_column(:teddies, :author_id, :integer) }
          .to raise_error(ActiveRecord::StatementInvalid, /relation "teddies_versions" does not exist/)
      end
    end
  end

  describe "#remove_temporal_column" do
    include_context "with a temporal table setup for books"

    it "removes a temporal column" do
      conn.remove_temporal_column(:books, :title)

      expect(:books_versions).to not_have_column(:title, :string)
    end

    context "when column does not exist on temporal table" do
      it "raises an error" do
        expect { conn.remove_temporal_column(:books, :publisher_id) }
          .to raise_error(ActiveRecord::StatementInvalid, /column "publisher_id" of relation "books_versions" does not exist/)
      end
    end

    context "when source table does not exist" do
      before { conn.drop_table(:books) }

      it "raises an error" do
        expect { conn.remove_temporal_column(:books, :title) }
          .to raise_error(ActiveRecord::StatementInvalid, /relation "books" does not exist/)
      end
    end

    context "when temporal table does not exist" do
      before { conn.drop_temporal_table(:books) }

      it "raises an error" do
        expect { conn.remove_temporal_column(:books, :title) }
          .to raise_error(ActiveRecord::StatementInvalid, /relation "books_versions" does not exist/)
      end
    end
  end
end
