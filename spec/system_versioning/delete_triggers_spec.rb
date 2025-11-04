require "spec_helper"

RSpec.describe "delete triggers" do
  before do
    system_versioned_table :books do |t|
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
    model "Book", ApplicationRecord
  end

  after do
    drop_all_tables
    conn.drop_schema("myschema", if_exists: true)
  end

  shared_examples "delete triggers" do
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
      it "does not create a history record" do
        conn.transaction do
          Book.create!(title: "The Great Gatsby", pages: 180)
          Book.first.destroy!
        end

        expect(Version::Book.count).to eq(0)
      end
    end
  end

  include_examples "delete triggers"

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

    include_examples "delete triggers"
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

    include_examples "delete triggers"
  end
end
