require "spec_helper"

RSpec.describe "deletes" do
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

  it "sets current temporal record's upper bound validity to the current time" do
    insert_time = transaction_with_time(conn) do
      Book.create!(title: "The Great Gatsby", pages: 180)
    end

    delete_time = transaction_with_time(conn) do
      Book.first.destroy!
    end

    expect(temporal_book_class.count).to eq(1)
    expect(temporal_book_class.first).to have_attributes(
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

      expect(temporal_book_class.count).to eq(1)
      expect(temporal_book_class.first).to have_attributes(
        title: "The Great Gatsby",
        pages: 180,
        validity: nil
      )
    end
  end
end
