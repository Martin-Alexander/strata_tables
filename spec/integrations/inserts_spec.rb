require "spec_helper"

RSpec.describe "inserts" do
  before do
    conn.create_strata_table(:books)
  end

  after do
    conn.drop_strata_table(:books)
    DatabaseCleaner.clean_with :truncation
  end

  let(:strata_book_class) do
    Class.new(ActiveRecord::Base) do
      def self.model_name
        ActiveModel::Name.new(self, nil, "StrataBook")
      end
    end
  end

  it "creates a new strata record" do
    insert_time = transaction_with_time(conn) do
      Book.create!(title: "The Great Gatsby", pages: 180)
    end

    expect(strata_book_class.count).to eq(1)
    expect(strata_book_class.first).to have_attributes(
      title: "The Great Gatsby",
      pages: 180,
      validity: insert_time...
    )
  end
end
