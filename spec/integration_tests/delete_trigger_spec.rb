require "spec_helper"

RSpec.describe "delete trigger" do
  let(:connection) { ActiveRecord::Base.connection }

  before do
    connection.create_history_triggers(:books, :history_books, [:id, :title, :pages, :published_at])
  end

  after do
    connection.drop_history_triggers(:history_books)
    DatabaseCleaner.clean_with :truncation
  end

  it "sets current history record's upper bound validity to the current time" do
    insert_time = transaction_with_time(connection) do
      connection.execute(<<~SQL.squish)
        INSERT INTO books (title, pages, published_at) VALUES ('The Great Gatsby', 180, '1925-04-10')
      SQL
    end

    delete_time = transaction_with_time(connection) do
      connection.execute(<<~SQL.squish)
        DELETE FROM books WHERE id = 1
      SQL
    end

    results = connection.execute("SELECT * FROM history_books")

    expect(results.count).to eq(1)
    expect(results[0]).to include(
      "title" => "The Great Gatsby",
      "pages" => 180,
      "published_at" => "1925-04-10",
      "validity" => be_tsrange.from(insert_time, :inclusive).to(delete_time, :exclusive),
    )
  end
end