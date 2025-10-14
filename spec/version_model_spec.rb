require "spec_helper"

RSpec.describe "version model" do
  before(:context) do
    conn.create_table(:authors) do |t|
      t.string :name
    end
    conn.create_history_table(:authors)

    randomize_sequences!(:id, :version_id)
  end

  after(:context) do
    conn.drop_table(:authors)
    conn.drop_history_table(:authors)
  end

  before do
    stub_const("ApplicationRecord", Class.new(ActiveRecord::Base) do
      self.abstract_class = true

      include StrataTables::Model
    end)
    stub_const("Author", Class.new(ApplicationRecord))
  end

  after do
    conn.truncate(:authors)
    conn.truncate(:authors__history)
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
      Author::Version.find_by!(name: "Bob")
    )
    expect(Author.as_of(t_2)).to contain_exactly(
      Author::Version.find_by!(name: "Bob"),
      Author::Version.find_by!(name: "Bill")
    )
    expect(Author.as_of(t_3)).to contain_exactly(
      Author::Version.find_by!(name: "Bill"),
      Author::Version.find_by!(name: "Bob 2")
    )
  end

  context "when the table name has spaces" do
    before do
      conn.create_table("My Books") do |t|
        t.string :name
        t.references :author, foreign_key: true
      end
      conn.create_history_table("My Books")

      randomize_sequences!(:id, :version_id)

      stub_const("Book", Class.new(ApplicationRecord) do
        self.table_name = "My Books"

        belongs_to :author
      end)
      stub_const("Author", Class.new(ApplicationRecord) do
        has_many :books
      end)

      Author::Version.reversionify
    end

    after do
      conn.drop_table("My Books")
      conn.drop_history_table("My Books")
    end

    it "::as_of filters by time" do
      t_0
      author = Author.create!(name: "Bob")
      t_1
      book = Book.create!(name: "Calliou")
      t_2
      book.update(author: author)
      t_3

      book_v1 = Book::Version.find_by(author_id: nil)
      book_v2 = Book::Version.where.not(author_id: nil).sole
      author_v1 = Author::Version.sole

      expect(Book::Version.as_of(t_0)).to be_empty
      expect(Book::Version.as_of(t_1)).to be_empty
      expect(Book::Version.as_of(t_2)).to contain_exactly(book_v1)
      expect(Book::Version.as_of(t_3)).to contain_exactly(book_v2)

      expect(Book::Version.as_of(t_2).joins(:author)).to be_empty
      expect(Book::Version.as_of(t_3).joins(:author)
        .where(authors__history: {name: "Bob"})).to contain_exactly(book_v2)

      rel = Author::Version.joins(:books).where("My Books__history" => {name: "Calliou"})

      expect(rel.as_of(t_0)).to be_empty
      expect(rel.as_of(t_1)).to be_empty
      expect(rel.as_of(t_2)).to be_empty
      expect(rel.as_of(t_3)).to contain_exactly(author_v1)
    end
  end
end
