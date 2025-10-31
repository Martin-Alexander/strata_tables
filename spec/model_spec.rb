require "spec_helper"

RSpec.describe "model" do
  before(:context) do
    conn.create_table(:countries) do |t|
      t.string :name
    end
    conn.create_table(:authors) do |t|
      t.string :name
      t.references :country
    end
    conn.create_table(:books) do |t|
      t.string :name
      t.references :author
    end

    conn.create_strata_metadata_table
    conn.create_history_table_for(:countries)
    conn.create_history_table_for(:authors)
    conn.create_history_table_for(:books)

    randomize_sequences!(:id, :version_id)
  end

  after(:context) do
    drop_all_tables
  end

  before do
    stub_const("ApplicationRecord", Class.new(ActiveRecord::Base) do
      self.abstract_class = true

      include StrataTables::Model
    end)
    stub_const("Country", Class.new(ApplicationRecord) do
      has_many :authors
    end)
    stub_const("Author", Class.new(ApplicationRecord) do
      belongs_to :country
      has_many :books
    end)
    stub_const("Book", Class.new(ApplicationRecord) do
      belongs_to :author
    end)

    t_0
    bob = Author.create!(name: "Bob")
    t_1
    Author.create!(name: "Bill")
    t_2
    bob.update(name: "Bob 2")
    t_3
  end

  after do
    truncate_all_tables(except: [:strata_metadata])
  end

  let(:author_bob) { Author.find_by!(name: "Bob 2") }
  let(:author_bill) { Author.find_by!(name: "Bill") }

  let(:author_bob_v1) { Author.version.find_by!(name: "Bob") }
  let(:author_bill_v1) { Author.version.find_by!(name: "Bill") }
  let(:author_bob_v2) { Author.version.find_by!(name: "Bob 2") }

  it "::version returns the model's version class" do
    expect(Author.table_name).to eq("authors")
    expect(Author.version).to be_an_instance_of(Class)
    expect(Author.version).to be < Author
    expect(Author.version).to be_include(StrataTables::VersionModel)
    expect(Author.version.name).to eq("Author::Version")
  end

  it "::versions queries the model's version class" do
    expect(Author.versions).to contain_exactly(author_bob_v1, author_bob_v2, author_bill_v1)
  end

  it "#as_of returns the latest version of the record" do
    expect(author_bob.as_of(t_0)).to be_nil
    expect(author_bob.as_of(t_1)).to eq(author_bob_v1)
    expect(author_bob.as_of(t_2)).to eq(author_bob_v1)
    expect(author_bob.as_of(t_3)).to eq(author_bob_v2)

    expect(author_bill.as_of(t_0)).to be_nil
    expect(author_bill.as_of(t_1)).to be_nil
    expect(author_bill.as_of(t_2)).to eq(author_bill_v1)
    expect(author_bill.as_of(t_3)).to eq(author_bill_v1)
  end

  it "#versions returns all versions of that record" do
    expect(author_bob.versions).to contain_exactly(author_bob_v1, author_bob_v2)
    expect(author_bill.versions).to contain_exactly(author_bill_v1)
  end

  it "version class is versionified" do
    expect(Author.version.table_name).to eq("authors_history")
    expect(Author.version.reflect_on_all_associations)
      .to all(have_attrs(klass: be_an_instance_of(Class)))
  end

  it "version module lockup can be overwritten" do
    stub_const("CountryHistory", Class.new(Country) do
      include StrataTables::VersionModel
    end)
    stub_const("AuthorHistory", Class.new(Author) do
      include StrataTables::VersionModel
    end)
    stub_const("BookHistory", Class.new(Book) do
      include StrataTables::VersionModel
    end)

    Country.define_singleton_method(:version) { CountryHistory }
    Author.define_singleton_method(:version) { AuthorHistory }
    Book.define_singleton_method(:version) { BookHistory }

    CountryHistory.reversionify
    AuthorHistory.reversionify
    BookHistory.reversionify

    expect(Country.version.reflect_on_association(:authors).klass).to eq(AuthorHistory)
    expect(Author.version.reflect_on_association(:country).klass).to eq(CountryHistory)
    expect(Author.version.reflect_on_association(:books).klass).to eq(BookHistory)
    expect(Book.version.reflect_on_association(:author).klass).to eq(AuthorHistory)
  end
end
