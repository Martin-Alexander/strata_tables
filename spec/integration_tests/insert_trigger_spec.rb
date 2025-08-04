require "spec_helper"

RSpec.describe "insert trigger" do
  let(:connection) { ActiveRecord::Base.connection }

  before do
    connection.create_history_triggers(:books, :history_books, [:id, :title, :pages])
  end

  after do
    connection.drop_history_triggers(:history_books)
    DatabaseCleaner.clean_with :truncation
  end

  it "creates a new history record" do
    insert_time = transaction_with_time(connection) do
      connection.execute("INSERT INTO books (title, pages) VALUES ('The Great Gatsby', 180)")
    end

    results = connection.execute("SELECT * FROM history_books")

    expect(results.count).to eq(1)
    expect(results.first).to include(
      "title" => "The Great Gatsby",
      "pages" => 180,
      "validity" => be_tsrange.from(insert_time, :inclusive)
    )
  end
end
