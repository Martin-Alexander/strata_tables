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

    conn.create_temporal_table(:countries)
    conn.create_temporal_table(:authors)
    conn.create_temporal_table(:books)
  end

  after(:context) do
    conn.drop_table(:countries)
    conn.drop_table(:authors)
    conn.drop_table(:books)

    conn.drop_temporal_table(:countries)
    conn.drop_temporal_table(:authors)
    conn.drop_temporal_table(:books)
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
  end

  after do
    conn.truncate(:countries)
    conn.truncate(:authors)
    conn.truncate(:books)
  end

  it "::version returns the model's version class" do
    expect(Author.table_name).to eq("authors")
    expect(Author.version).to be_an_instance_of(Class)
    expect(Author.version).to be < Author
    expect(Author.version).to be_include(StrataTables::VersionModel)
    expect(Author.version.name).to eq("Author::Version")
  end

  it "version class is versionified" do
    expect(Author.version.table_name).to eq("authors_versions")
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
