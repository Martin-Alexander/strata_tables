require "spec_helper"

RSpec.describe "update triggers" do
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

  it "sets current history record's upper bound system_period to the current time and creates a new history record" do
    insert_time = transaction_with_time(conn) do
      Book.create!(title: "The Great Gatsby", pages: 180)
    end

    update_time = transaction_with_time(conn) do
      Book.first.update!(title: "The Greatest Gatsby")
    end

    expect(Version::Book.count).to eq(2)
    expect(Version::Book.find_by(title: "The Great Gatsby"))
      .to have_attributes(pages: 180, system_period: insert_time...update_time)
    expect(Version::Book.find_by(title: "The Greatest Gatsby"))
      .to have_attributes(pages: 180, system_period: update_time...)
  end

  context "when the update doesn't change the record" do
    it "does not change the history table" do
      insert_time = transaction_with_time(conn) do
        Book.create!(title: "The Great Gatsby", pages: 180)
      end

      Book.first.update!(title: "The Great Gatsby")

      expect(Version::Book.count).to eq(1)
      expect(Version::Book.first).to have_attributes(
        title: "The Great Gatsby",
        pages: 180,
        system_period: insert_time...
      )
    end
  end

  context "when two updates are made in a single transaction" do
    it "creates two history records with the first having an empty system_period range" do
      skip

      insert_time = transaction_with_time(conn) do
        Book.create!(title: "The Great Gatsby", pages: 180)
      end

      update_time = transaction_with_time(conn) do
        Book.first.update!(title: "The Greatest Gatsby")
        Book.first.update!(title: "The Absolutely Greatest Gatsby")
      end

      expect(Version::Book.count).to eq(3)
      expect(Version::Book.find_by(title: "The Great Gatsby"))
        .to have_attributes(
          title: "The Great Gatsby",
          pages: 180,
          system_period: insert_time...update_time
        )
      expect(Version::Book.find_by(title: "The Greatest Gatsby"))
        .to have_attributes(
          title: "The Greatest Gatsby",
          pages: 180,
          system_period: nil
        )
      expect(Version::Book.find_by(title: "The Absolutely Greatest Gatsby"))
        .to have_attributes(
          title: "The Absolutely Greatest Gatsby",
          pages: 180,
          system_period: update_time...
        )
    end
  end
end
