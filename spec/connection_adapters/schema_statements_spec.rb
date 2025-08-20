require "spec_helper"

RSpec.describe StrataTables::ConnectionAdapters::SchemaStatements do
  around do |example|
    DatabaseCleaner.cleaning { example.run }
  end

  RSpec.shared_context "with a strata table setup for books" do
    before { conn.create_strata_table(:books) }
  end

  describe "#create_strata_table" do
    it "creates a strata table" do
      conn.create_strata_table(:books)

      expect(conn).to have_table(:books_versions)

      expect(:books).to have_strata_table

      expect(:books_versions)
        .to have_column(:id, :integer)
        .and have_column(:title, :string, null: false, limit: 100)
        .and have_column(:price, :decimal, precision: 10, scale: 2)
        .and have_column(:summary, :string, collation: "en_US.utf8")
        .and have_column(:pages, :integer, comment: "Number of pages")
        # TODO: support old and new version of the `#column_exists?` method
        # .and have_column(:published_at, :date, default: Date.new(2025, 1, 1))
        .and have_column(:published_at, :date)
        .and have_column(:author_id, :integer)
    end

    context "when source table does not exist" do
      it "raises an error" do
        expect { conn.create_strata_table(:teddies) }
          .to raise_error(ActiveRecord::StatementInvalid, /relation "teddies" does not exist/)
      end
    end
  end

  describe "#drop_strata_table" do
    include_context "with a strata table setup for books"

    it "drops a strata table" do
      conn.drop_strata_table(:books)

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

  describe "#add_strata_column" do
    include_context "with a strata table setup for books"

    it "adds a strata column" do
      conn.add_strata_column(:books, :subtitle, :string)

      expect(:books_versions).to have_column(:subtitle, :string)
    end

    context "when source table does not exist" do
      it "raises an error" do
        expect { conn.add_strata_column(:teddies, :author_id, :integer) }
          .to raise_error(ActiveRecord::StatementInvalid, /relation "teddies_versions" does not exist/)
      end
    end

    context "when strata table does not exist" do
      before { conn.create_table(:teddies) }

      it "raises an error" do
        expect { conn.add_strata_column(:teddies, :author_id, :integer) }
          .to raise_error(ActiveRecord::StatementInvalid, /relation "teddies_versions" does not exist/)
      end
    end
  end

  describe "#remove_strata_column" do
    include_context "with a strata table setup for books"

    it "removes a strata column" do
      conn.remove_strata_column(:books, :title)

      expect(:books_versions).to not_have_column(:title, :string)
    end

    context "when column does not exist on strata table" do
      it "raises an error" do
        expect { conn.remove_strata_column(:books, :publisher_id) }
          .to raise_error(ActiveRecord::StatementInvalid, /column "publisher_id" of relation "books_versions" does not exist/)
      end
    end

    context "when source table does not exist" do
      before { conn.drop_table(:books) }

      it "raises an error" do
        expect { conn.remove_strata_column(:books, :title) }
          .to raise_error(ActiveRecord::StatementInvalid, /relation "books" does not exist/)
      end
    end

    context "when strata table does not exist" do
      before { conn.drop_strata_table(:books) }

      it "raises an error" do
        expect { conn.remove_strata_column(:books, :title) }
          .to raise_error(ActiveRecord::StatementInvalid, /relation "books_versions" does not exist/)
      end
    end
  end
end
