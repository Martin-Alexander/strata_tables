require "spec_helper"

RSpec.describe "version model" do
  before(:context) do
    conn.create_table(:authors) do |t|
      t.string :name
    end

    conn.create_strata_metadata_table
    conn.create_history_table_for(:authors)

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
    stub_const("Author", Class.new(ApplicationRecord))
  end

  after do
    truncate_all_tables(except: [:strata_metadata])
  end

  it "::as_of is delegated to ::all" do
    t_0
    bob = Author.create!(name: "Bob")
    t_1
    Author.create!(name: "Bill")
    t_2
    bob.update(name: "Bob 2")
    t_3

    expect(Author.as_of(t_0)).to be_empty
    expect(Author.as_of(t_1)).to contain_exactly(
      Author.version.find_by!(name: "Bob")
    )
    expect(Author.as_of(t_2)).to contain_exactly(
      Author.version.find_by!(name: "Bob"),
      Author.version.find_by!(name: "Bill")
    )
    expect(Author.as_of(t_3)).to contain_exactly(
      Author.version.find_by!(name: "Bill"),
      Author.version.find_by!(name: "Bob 2")
    )
  end

  # it "::version_of returns the source class" do
  #   expect(Author.version.version_of).to eq(Author)
  #   expect(Author.version.version_of.name).to eq("Author")
  # end

  context "when the table name has spaces" do
    before(:context) do
      conn.create_table("My Books") do |t|
        t.string :name
        t.references :author, foreign_key: true
      end
      conn.create_history_table_for("My Books")

      randomize_sequences!(:id, :version_id)
    end

    before do
      stub_const("Book", Class.new(ApplicationRecord) do
        self.table_name = "My Books"

        belongs_to :author
      end)
      stub_const("Author", Class.new(ApplicationRecord) do
        has_many :books
      end)

      Author.version.reversionify
    end

    it "::as_of filters by time" do
      t_0
      author = Author.create!(name: "Bob")
      t_1
      book = Book.create!(name: "Calliou")
      t_2
      book.update(author: author)
      t_3

      book_v1 = Book.version.find_by(author_id: nil)
      book_v2 = Book.version.where.not(author_id: nil).sole
      author_v1 = Author.version.sole

      expect(Book.version.as_of(t_0)).to be_empty
      expect(Book.version.as_of(t_1)).to be_empty
      expect(Book.version.as_of(t_2)).to contain_exactly(book_v1)
      expect(Book.version.as_of(t_3)).to contain_exactly(book_v2)

      expect(Book.version.as_of(t_2).joins(:author)).to be_empty
      expect(Book.version.as_of(t_3).joins(:author)
        .where(authors_history: {name: "Bob"})).to contain_exactly(book_v2)

      rel = Author.version.joins(:books).where("My Books_history" => {name: "Calliou"})

      expect(rel.as_of(t_0)).to be_empty
      expect(rel.as_of(t_1)).to be_empty
      expect(rel.as_of(t_2)).to be_empty
      expect(rel.as_of(t_3)).to contain_exactly(author_v1)
    end
  end
end
