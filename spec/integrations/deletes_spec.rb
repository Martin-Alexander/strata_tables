require "spec_helper"

RSpec.describe "deletes" do
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

  it "sets current temporal record's upper bound validity to the current time" do
    insert_time = transaction_with_time(conn) do
      Book.create!(title: "The Great Gatsby", pages: 180)
    end

    delete_time = transaction_with_time(conn) do
      Book.first.destroy!
    end

    expect(Book::Version.count).to eq(1)
    expect(Book::Version.first).to have_attributes(
      title: "The Great Gatsby",
      pages: 180,
      validity: insert_time...delete_time
    )
  end

  context "when inserting and deleting in a single transaction" do
    it "creates a temporal record with an empty validity range" do
      conn.transaction do
        Book.create!(title: "The Great Gatsby", pages: 180)
        Book.first.destroy!
      end

      expect(Book::Version.count).to eq(1)
      expect(Book::Version.first).to have_attributes(
        title: "The Great Gatsby",
        pages: 180,
        validity: nil
      )
    end
  end
end
