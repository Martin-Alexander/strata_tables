require "spec_helper"

RSpec.describe "insert triggers" do
  before do
    system_versioned_table :books do |t|
      t.string :title
      t.integer :pages
    end

    stub_const("Version", Module.new do
      include SystemVersioningNamespace
    end)

    model "ApplicationRecord" do
      self.abstract_class = true

      include SystemVersioning

      system_versioning
    end
    model "Book", ApplicationRecord
  end

  after do
    drop_all_tables
    drop_all_versioning_hooks
    conn.drop_schema("myschema", if_exists: true)
  end

  shared_examples "insert triggers" do
    it "creates a new history record" do
      insert_time = transaction_with_time(conn) do
        Book.create!(title: "The Great Gatsby", pages: 180)
      end

      expect(Version::Book.count).to eq(1)
      expect(Version::Book.first).to have_attributes(
        title: "The Great Gatsby",
        pages: 180,
        system_period: insert_time...
      )
    end
  end

  include_examples "insert triggers"

  context "when the table name has spaces" do
    before do
      system_versioned_table "My Books" do |t|
        t.string :title
        t.integer :pages
      end

      model "Book", ApplicationRecord do
        self.table_name = "My Books"
      end
    end

    include_examples "insert triggers"
  end

  context "when the table name is schema qualified" do
    before do
      conn.create_schema("myschema")

      system_versioned_table "myschema.books" do |t|
        t.string :title
        t.integer :pages
      end

      model "Book", ApplicationRecord do
        self.table_name = "myschema.books"
      end
    end

    include_examples "insert triggers"
  end
end
