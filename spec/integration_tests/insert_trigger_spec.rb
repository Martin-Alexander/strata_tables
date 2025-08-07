require "spec_helper"

RSpec.describe "insert trigger" do
  conn = ActiveRecord::Base.connection

  before do
    conn.create_strata_table(:books)
  end

  after do
    conn.drop_strata_table(:books)
    DatabaseCleaner.clean_with :truncation
  end

  it "creates a new strata record" do
    insert_time = transaction_with_time(conn) do
      conn.execute("INSERT INTO books (title, pages) VALUES ('The Great Gatsby', 180)")
    end

    results = conn.execute("SELECT * FROM strata_books")

    expect(results.count).to eq(1)
    expect(results.first).to include(
      "title" => "The Great Gatsby",
      "pages" => 180,
      "validity" => be_tsrange.from(insert_time, :inclusive)
    )
  end
end
