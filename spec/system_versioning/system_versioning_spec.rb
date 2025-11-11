require "spec_helper"

RSpec.describe "system versioning" do
  before do
    conn.enable_extension(:btree_gist)

    stub_const("Version", Module.new do
      include SystemVersioningNamespace
    end)

    model "ApplicationRecord" do
      self.abstract_class = true

      include SystemVersioning

      system_versioning
    end
  end

  after do
    drop_all_tables
    drop_all_versioning_hooks
    conn.disable_extension(:btree_gist)
  end

  shared_examples "versions records" do
    it "versions records" do
      t1 = transaction_time { Author.create!(name: "Will") }
      t2 = transaction_time { Author.first.update!(name: "Bob") }
      t3 = transaction_time { Author.first.destroy }
      t4 = transaction_time { Author.create!(name: "Sam") }
      t5 = transaction_time do
        Author.last.update(name: "Bill")
        Author.last.update(name: "Egbert")
      end

      expect(Version::Author.count).to eq(4)

      expect(Version::Author.first)
        .to have_attributes(name: "Will", system_period: t1...t2)
      expect(Version::Author.second)
        .to have_attributes(name: "Bob", system_period: t2...t3)
      expect(Version::Author.third)
        .to have_attributes(name: "Sam", system_period: t4...t5)
      expect(Version::Author.fourth)
        .to have_attributes(name: "Egbert", system_period: t5...)
    end
  end

  context "source table primary key is 'id'" do
    before do
      conn.create_table :authors do |t|
        t.string :name
      end

      conn.create_table :authors_history, primary_key: [:id, :system_period] do |t|
        t.bigint :id, null: false
        t.string :name
        t.tstzrange :system_period, null: false
        t.exclusion_constraint "id WITH =, system_period WITH &&", using: :gist
      end

      conn.create_versioning_hook(
        :authors,
        :authors_history,
        columns: [:id, :name]
      )

      model "Author", ApplicationRecord
    end

    include_examples "versions records"
  end

  context "source table primary key is (id, author_number)" do
    before do
      conn.create_table :authors, primary_key: [:id, :author_number] do |t|
        t.bigserial :id, null: false
        t.bigserial :author_number, null: false
        t.string :name
      end

      conn.create_table :authors_history, primary_key: [:id, :author_number, :system_period] do |t|
        t.bigint :id, null: false
        t.bigint :author_number, null: false
        t.string :name
        t.tstzrange :system_period, null: false
        t.exclusion_constraint "id WITH =, system_period WITH &&", using: :gist
      end

      conn.create_versioning_hook(
        :authors,
        :authors_history,
        columns: [:id, :name, :author_number],
        primary_key: [:id, :author_number]
      )

      model "Author", ApplicationRecord
    end

    it "version model has correct primary key" do
      expect(Version::Author.primary_key).to eq(%w[id author_number system_period])
    end

    include_examples "versions records"
  end
end
