require "spec_helper"

RSpec.describe "updates" do
  before do
    conn.create_temporal_table(:books)
  end

  after do
    conn.drop_temporal_table(:books)
    DatabaseCleaner.clean_with :truncation
  end

  let(:temporal_book_class) do
    Class.new(ActiveRecord::Base) do
      def self.model_name
        ActiveModel::Name.new(self, nil, "BooksVersion")
      end
    end
  end

  it "sets current temporal record's upper bound validity to the current time and creates a new temporal record" do
    insert_time = transaction_with_time(conn) do
      Book.create!(title: "The Great Gatsby", pages: 180)
    end

    update_time = transaction_with_time(conn) do
      Book.first.update!(title: "The Greatest Gatsby")
    end

    expect(temporal_book_class.count).to eq(2)
    expect(temporal_book_class.find_by(title: "The Great Gatsby")).to have_attributes(
      pages: 180,
      validity: insert_time...update_time
    )
    expect(temporal_book_class.find_by(title: "The Greatest Gatsby")).to have_attributes(
      pages: 180,
      validity: update_time...
    )
  end

  context "when the update doesn't change the record" do
    it "does not change the temporal table" do
      insert_time = transaction_with_time(conn) do
        Book.create!(title: "The Great Gatsby", pages: 180)
      end

      Book.first.update!(title: "The Great Gatsby")

      expect(temporal_book_class.count).to eq(1)
      expect(temporal_book_class.first).to have_attributes(
        title: "The Great Gatsby",
        pages: 180,
        validity: insert_time...
      )
    end
  end

  context "when two updates are made in a single transaction" do
    it "creates two temporal records with the first having an empty validity range" do
      insert_time = transaction_with_time(conn) do
        Book.create!(title: "The Great Gatsby", pages: 180)
      end

      update_time = transaction_with_time(conn) do
        Book.first.update!(title: "The Greatest Gatsby")
        Book.first.update!(title: "The Absolutely Greatest Gatsby")
      end

      expect(temporal_book_class.count).to eq(3)
      expect(temporal_book_class.find_by(title: "The Great Gatsby")).to have_attributes(
        title: "The Great Gatsby",
        pages: 180,
        validity: insert_time...update_time
      )
      expect(temporal_book_class.find_by(title: "The Greatest Gatsby")).to have_attributes(
        title: "The Greatest Gatsby",
        pages: 180,
        validity: nil
      )
      expect(temporal_book_class.find_by(title: "The Absolutely Greatest Gatsby")).to have_attributes(
        title: "The Absolutely Greatest Gatsby",
        pages: 180,
        validity: update_time...
      )
    end
  end
end
