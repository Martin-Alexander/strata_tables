require "spec_helper"

RSpec.describe "insert triggers" do
  before do
    system_versioned_table :cooks do |t|
      t.string :title
      t.integer :pages
    end

    stub_const("Version", Module.new do
      include StrataTables::SystemVersioningNamespace
    end)

    model "ApplicationRecord" do
      self.abstract_class = true

      include StrataTables::SystemVersioning

      system_versioning
    end
    model "Cook", ApplicationRecord
  end

  after do
    drop_all_tables
  end

  it "creates a new history record" do
    insert_time = transaction_with_time(conn) do
      Cook.create!(title: "The Great Gatsby", pages: 180)
    end

    expect(Version::Cook.count).to eq(1)
    expect(Version::Cook.first).to have_attributes(
      title: "The Great Gatsby",
      pages: 180,
      system_period: insert_time...
    )
  end
end
