require "spec_helper"

RSpec.describe "insert triggers" do
  before do
    conn.create_table(:books) do |t|
      t.string :title
      t.integer :pages
    end
    conn.create_temporal_table(:books)
    stub_const("Book", Class.new(ActiveRecord::Base))
    stub_const("Book::Version", Class.new(Book) { include StrataTables::VersionModel })
  end

  after do
    conn.drop_table(:books)
    conn.drop_temporal_table(:books)
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
