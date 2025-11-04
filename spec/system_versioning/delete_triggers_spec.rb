require "spec_helper"

RSpec.describe "delete triggers" do
  before do
    system_versioned_table :books do |t|
      t.string :title
      t.integer :pages
    end

    model "ApplicationRecord" do
      self.abstract_class = true

      include StrataTables::SystemVersioning

      system_versioning
    end
    model "Book", ApplicationRecord
  end

  after do
    drop_all_tables
  end

  it "sets current history record's upper bound system_period to the current time" do
    insert_time = transaction_with_time(conn) do
      Book.create!(title: "The Great Gatsby", pages: 180)
    end

    delete_time = transaction_with_time(conn) do
      Book.first.destroy!
    end

    expect(Version::Book.count).to eq(1)
    expect(Version::Book.first).to have_attributes(
      title: "The Great Gatsby",
      pages: 180,
      system_period: insert_time...delete_time
    )
  end

  context "when inserting and deleting in a single transaction" do
    it "creates a history record with an empty system_period range" do
      skip

      conn.transaction do
        Book.create!(title: "The Great Gatsby", pages: 180)
        Book.first.destroy!
      end

      expect(Version::Book.count).to eq(1)
      expect(Version::Book.first).to have_attributes(
        title: "The Great Gatsby",
        pages: 180,
        system_period: nil
      )
    end
  end
end
