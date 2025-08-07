require "spec_helper"

RSpec.describe "delete trigger" do
  let(:connection) { ActiveRecord::Base.connection }

  before do
    connection.create_strata_triggers(:books, strata_table: :strata_books, columns: [:id, :title, :pages])
  end

  after do
    connection.drop_strata_triggers(:books, strata_table: :strata_books)
    DatabaseCleaner.clean_with :truncation
  end

  it "sets current strata record's upper bound validity to the current time" do
    insert_time = transaction_with_time(connection) do
      connection.execute("INSERT INTO books (title, pages) VALUES ('The Great Gatsby', 180)")
    end

    delete_time = transaction_with_time(connection) do
      connection.execute("DELETE FROM books WHERE id = 1")
    end

    results = connection.execute("SELECT * FROM strata_books")

    expect(results.count).to eq(1)
    expect(results[0]).to include(
      "title" => "The Great Gatsby",
      "pages" => 180,
      "validity" => be_tsrange.from(insert_time, :inclusive).to(delete_time, :exclusive)
    )
  end

  context "when inserting and deleting in a single transaction" do
    it "creates a strata record with an empty validity range" do
      connection.transaction do
        connection.execute("INSERT INTO books (title, pages) VALUES ('The Great Gatsby', 180)")
        connection.execute("DELETE FROM books WHERE id = 1")
      end

      results = connection.execute("SELECT * FROM strata_books")

      expect(results.count).to eq(1)
      expect(results[0]).to include(
        "title" => "The Great Gatsby",
        "pages" => 180,
        "validity" => be_tsrange.empty
      )
    end
  end
end
