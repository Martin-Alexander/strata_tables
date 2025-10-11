require "spec_helper"

RSpec.describe "update triggers" do
  before do
    conn.create_table(:books) do |t|
      t.string :title
      t.integer :pages
    end
    conn.create_history_table(:books)
    stub_const("Book", Class.new(ActiveRecord::Base))
    stub_const("Book::Version", Class.new(Book) do
      include StrataTables::VersionModel
    end)
  end

  after do
    conn.drop_table(:books)
    conn.drop_history_table(:books)
  end

  it "sets current history record's upper bound validity to the current time and creates a new history record" do
    insert_time = transaction_with_time(conn) do
      Book.create!(title: "The Great Gatsby", pages: 180)
    end

    update_time = transaction_with_time(conn) do
      Book.first.update!(title: "The Greatest Gatsby")
    end

    expect(Book::Version.count).to eq(2)
    expect(Book::Version.find_by(title: "The Great Gatsby"))
      .to have_attributes(pages: 180, validity: insert_time...update_time)
    expect(Book::Version.find_by(title: "The Greatest Gatsby"))
      .to have_attributes(pages: 180, validity: update_time...)
  end

  context "when the update doesn't change the record" do
    it "does not change the history table" do
      insert_time = transaction_with_time(conn) do
        Book.create!(title: "The Great Gatsby", pages: 180)
      end

      Book.first.update!(title: "The Great Gatsby")

      expect(Book::Version.count).to eq(1)
      expect(Book::Version.first).to have_attributes(
        title: "The Great Gatsby",
        pages: 180,
        validity: insert_time...
      )
    end
  end

  context "when two updates are made in a single transaction" do
    it "creates two history records with the first having an empty validity range" do
      insert_time = transaction_with_time(conn) do
        Book.create!(title: "The Great Gatsby", pages: 180)
      end

      update_time = transaction_with_time(conn) do
        Book.first.update!(title: "The Greatest Gatsby")
        Book.first.update!(title: "The Absolutely Greatest Gatsby")
      end

      expect(Book::Version.count).to eq(3)
      expect(Book::Version.find_by(title: "The Great Gatsby"))
        .to have_attributes(
          title: "The Great Gatsby",
          pages: 180,
          validity: insert_time...update_time
        )
      expect(Book::Version.find_by(title: "The Greatest Gatsby"))
        .to have_attributes(
          title: "The Greatest Gatsby",
          pages: 180,
          validity: nil
        )
      expect(Book::Version.find_by(title: "The Absolutely Greatest Gatsby"))
        .to have_attributes(
          title: "The Absolutely Greatest Gatsby",
          pages: 180,
          validity: update_time...
        )
    end
  end
end
