require "spec_helper"

RSpec.describe "delete triggers" do
  before do
    conn.create_table(:books) do |t|
      t.string :title
      t.integer :pages
    end
    conn.create_history_table(:books)

    randomize_sequences!(:id, :version_id)

    stub_const("Book", Class.new(ActiveRecord::Base))
    stub_const("Book::Version", Class.new(Book) do
      include StrataTables::VersionModel
    end)
  end

  after do
    conn.drop_table(:books)
    conn.drop_history_table(:books)
  end

  it "sets current history record's upper bound sys_period to the current time" do
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
      sys_period: insert_time...delete_time
    )
  end

  context "when inserting and deleting in a single transaction" do
    it "creates a history record with an empty sys_period range" do
      conn.transaction do
        Book.create!(title: "The Great Gatsby", pages: 180)
        Book.first.destroy!
      end

      expect(Book::Version.count).to eq(1)
      expect(Book::Version.first).to have_attributes(
        title: "The Great Gatsby",
        pages: 180,
        sys_period: nil
      )
    end
  end
end
