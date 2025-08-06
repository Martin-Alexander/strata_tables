require "spec_helper"

RSpec.describe "update trigger" do
  let(:conn) { ActiveRecord::Base.connection }

  before do
    conn.create_strata_triggers(:strata_books, :books, [:id, :title, :pages])
  end

  after do
    conn.drop_strata_triggers(:strata_books)
    DatabaseCleaner.clean_with :truncation
  end

  it "sets current strata record's upper bound validity to the current time and creates a new strata record" do
    insert_time = transaction_with_time(conn) do
      conn.execute("INSERT INTO books (title, pages) VALUES ('The Great Gatsby', 180)")
    end

    update_time = transaction_with_time(conn) do
      conn.execute("UPDATE books SET title = 'The Greatest Gatsby' WHERE id = 1")
    end

    results = conn.execute("SELECT * FROM strata_books")

    expect(results.count).to eq(2)
    expect(results[0]).to include(
      "title" => "The Great Gatsby",
      "pages" => 180,
      "validity" => be_tsrange.from(insert_time, :inclusive).to(update_time, :exclusive)
    )
    expect(results[1]).to include(
      "title" => "The Greatest Gatsby",
      "pages" => 180,
      "validity" => be_tsrange.from(update_time, :inclusive)
    )
  end

  context "when the update doesn't change the record" do
    it "does not change the strata table" do
      insert_time = transaction_with_time(conn) do
        conn.execute("INSERT INTO books (title, pages) VALUES ('The Great Gatsby', 180)")
      end

      conn.execute("UPDATE books SET title = 'The Great Gatsby' WHERE id = 1")

      results = conn.execute("SELECT * FROM strata_books")

      expect(results.count).to eq(1)
      expect(results[0]).to include(
        "title" => "The Great Gatsby",
        "pages" => 180,
        "validity" => be_tsrange.from(insert_time, :inclusive)
      )
    end
  end

  context "when two updates are made in a single transaction" do
    it "creates two strata records with the first having an empty validity range" do
      insert_time = transaction_with_time(conn) do
        conn.execute("INSERT INTO books (title, pages) VALUES ('The Great Gatsby', 180)")
      end

      update_time = transaction_with_time(conn) do
        conn.execute("UPDATE books SET title = 'The Greatest Gatsby' WHERE id = 1")
        conn.execute("UPDATE books SET title = 'The Absolutely Greatest Gatsby' WHERE id = 1")
      end

      results = conn.execute("SELECT * FROM strata_books")

      expect(results.count).to eq(3)
      expect(results[0]).to include(
        "title" => "The Great Gatsby",
        "pages" => 180,
        "validity" => be_tsrange.from(insert_time, :inclusive).to(update_time, :exclusive)
      )
      expect(results[1]).to include(
        "title" => "The Greatest Gatsby",
        "pages" => 180,
        "validity" => be_tsrange.empty
      )
      expect(results[2]).to include(
        "title" => "The Absolutely Greatest Gatsby",
        "pages" => 180,
        "validity" => be_tsrange.from(update_time, :inclusive)
      )
    end
  end
end
