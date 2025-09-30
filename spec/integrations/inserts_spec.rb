require "spec_helper"

RSpec.describe "inserts" do
  before do
    setup_tables(:books) do |t|
      t.string :title
      t.integer :pages
    end
    setup_model("Book")
    setup_version_model("Book")
  end

  after do
    teardown_tables(:books)
  end

  it "creates a new temporal record" do
    insert_time = transaction_with_time(conn) do
      Book.create!(title: "The Great Gatsby", pages: 180)
    end

    expect(Book::Version.count).to eq(1)
    expect(Book::Version.first).to have_attributes(
      title: "The Great Gatsby",
      pages: 180,
      validity: insert_time...
    )
  end
end
