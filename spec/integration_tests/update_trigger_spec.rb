require "spec_helper"

RSpec.describe "update trigger" do
  let(:conn) { ActiveRecord::Base.connection }

  before do
    conn.create_history_triggers(:books, :history_books, [:id, :title, :pages, :published_at])
  end

  after do
    conn.drop_history_triggers(:history_books)
    DatabaseCleaner.clean_with :truncation
  end

  it "sets current history record's upper bound validity to the current time and creates a new history record" do
    insert_time = transaction_with_time(conn) do
      conn.execute(<<~SQL.squish)
        INSERT INTO books (title, pages, published_at) VALUES ('The Great Gatsby', 180, '1925-04-10')
      SQL
    end

    update_time = transaction_with_time(conn) do
      conn.execute(<<~SQL.squish)
        UPDATE books SET title = 'The Greatest Gatsby' WHERE id = 1
      SQL
    end

    results = conn.execute("SELECT * FROM history_books")

    expect(results.count).to eq(2)
    expect(results[0]).to include(
      "title" => "The Great Gatsby",
      "pages" => 180,
      "published_at" => "1925-04-10",
      "validity" => be_tsrange.from(insert_time, :inclusive).to(update_time, :exclusive),
    )
    expect(results[1]).to include(
      "title" => "The Greatest Gatsby",
      "pages" => 180,
      "published_at" => "1925-04-10",
      "validity" => be_tsrange.from(update_time, :inclusive),
    )
  end

  context "when the update doesn't change the record" do
    it "does not change the history table" do
      insert_time = transaction_with_time(conn) do
        conn.execute(<<~SQL.squish)
          INSERT INTO books (title, pages, published_at) VALUES ('The Great Gatsby', 180, '1925-04-10')
        SQL
      end

      conn.execute(<<~SQL.squish)
        UPDATE books SET title = 'The Great Gatsby' WHERE id = 1
      SQL

      results = conn.execute("SELECT * FROM history_books")

      expect(results.count).to eq(1)
      expect(results[0]).to include(
        "title" => "The Great Gatsby",
        "pages" => 180,
        "published_at" => "1925-04-10",
        "validity" => be_tsrange.from(insert_time, :inclusive),
      )
    end
  end
end