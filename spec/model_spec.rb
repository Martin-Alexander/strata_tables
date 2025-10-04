require "spec_helper"

RSpec.describe StrataTables::Model do
  before do
    conn.create_table(:authors) do |t|
      t.string :name
    end
    conn.create_table(:books) do |t|
      t.string :name
      t.references :author
    end

    stub_const("Author", Class.new(ActiveRecord::Base) do
      has_many :books
    end)
    stub_const("Book", Class.new(ActiveRecord::Base) do
      belongs_to :author
    end)
    stub_const("Author::Version", Class.new(Author) { include StrataTables::Model })
    stub_const("Book::Version", Class.new(Book) { include StrataTables::Model })
  end

  after do
    conn.drop_table(:authors)
    conn.drop_table(:books)
  end

  context "temporal table" do
    before do
      conn.create_temporal_table(:authors)
      conn.create_temporal_table(:books)

      Author::Version.reversionify
      Book::Version.reversionify
    end

    after do
      conn.drop_temporal_table(:authors)
      conn.drop_temporal_table(:books)
    end

    it "::table_name return the temporal table" do
      expect(Author::Version.table_name).to eq("authors_versions")
    end

    describe "has_many associations" do
      before do
        @author = Author.create(name: "Bob")
        @author.update(name: "Billy Bob")
        book = Book.create(author: @author)
        book.update(name: "Calliou")
      end

      def author_v1 = Author::Version.find_by(name: "Bob")
      def author_v2 = Author::Version.find_by(name: "Billy Bob")

      it "target is instances of Book::Version" do
        expect(author_v2.books).to all(be_an_instance_of(Book::Version))
      end

      it "scopes target to owner's validity" do
        expect(author_v1.books.count).to eq(0)
        expect(author_v2.books.sole).to have_attributes(name: "Calliou")
      end

      context "when the base assocation has a scope" do
        before do
          Author.has_many(
            :calliou_books,
            -> { where(name: "Calliou") },
            class_name: "Book"
          )
          Author::Version.reversionify

          Book.create(author: @author, name: "Not Calliou")
        end

        it "scopes target to owner's validity without overriding" do
          expect(author_v1.calliou_books.count).to eq(0)
          expect(author_v2.calliou_books.sole.name).to eq("Calliou")
        end
      end

      context "when the base assocation has an instance dependent scope" do
        before do
          Author.has_many(
            :self_titled_books,
            ->(o) { where(name: o.name) },
            class_name: "Book"
          )
          Author::Version.reversionify

          Book.create(author: @author, name: "Bob")
          Book.create(author: @author, name: "Billy Bob")
        end

        it "scopes target to owner's validity without overriding" do
          expect(author_v1.self_titled_books.count).to eq(0)
          expect(author_v2.self_titled_books.sole.name).to eq("Billy Bob")
        end
      end

      it "does not prevent preload loading" do
        authors = Author::Version.preload(:books)

        expect(authors.count).to eq(2)
        expect(authors.first.books.size).to eq(0)
        expect(authors.last.books.size).to eq(1)
      end

      it "does not prevent eager loading" do
        authors = Author::Version.eager_load(:books)

        expect(authors.count).to eq(2)
        expect(authors.first.books.size).to eq(2)
        expect(authors.last.books.size).to eq(2)
      end
    end

    describe "belongs_to associations" do
      before do
        @author = Author.create(name: "Bob")
        book = Book.create(author: @author, name: "Calliou")
        book.update(name: "Calliou 2")
        @author.update(name: "Billy Bob")
      end

      def book_v1 = Book::Version.find_by(name: "Calliou")
      def book_v2 = Book::Version.find_by(name: "Calliou 2")

      it "target is instance of Author::Version" do
        expect(book_v1.author).to be_an_instance_of(Author::Version)
      end

      it "scopes target to owner's validity" do
        expect(book_v1.author.name).to eq("Bob")
        expect(book_v2.author.name).to eq("Billy Bob")
      end

      context "when the base assocation has a scope" do
        before do
          Book.belongs_to(
            :bob_author,
            -> { where(name: "Bob") },
            class_name:  "Author",
            foreign_key: :author_id
          )
          Book::Version.reversionify
        end

        it "scopes target to owner's validity without overriding" do
          expect(book_v1.bob_author.name).to eq("Bob")
          expect(book_v2.bob_author).to be_nil
        end
      end

      context "when the base assocation has an instance dependent scope" do
        before do
         Book.belongs_to(
            :self_titled_author,
            ->(o) { where(name: o.name) },
            class_name:  "Author",
            foreign_key: :author_id
          )
          Book::Version.reversionify
        end

        it "scopes target to owner's validity without overriding" do
          expect(book_v1.self_titled_author).to be_nil
          expect(book_v2.self_titled_author).to be_nil

          @author.update(name: "Calliou")

          expect(book_v1.self_titled_author).to be_nil
          expect(book_v2.self_titled_author).to be_nil

          @author.update(name: "Calliou 2")

          expect(book_v1.self_titled_author).to be_nil
          expect(book_v2.self_titled_author.name).to eq("Calliou 2")
        end
      end
    end

    it "books association returns book_version records" do
      Author.create(name: "Bob").books.create

      expect(Author::Version.first.books).to all(be_an_instance_of(Book::Version))
    end
  end

  context "regular table" do
    it "::table_name returns the original table" do
      expect(Author::Version.table_name).to eq("authors")
    end

    describe "has_many associations" do
      before do
        conn.create_temporal_table(:books)

        Author::Version.reversionify
        Book::Version.reversionify

        author = Author.create(name: "Bob")
        author.update(name: "Billy Bob")
        book = Book.create(author: author)
        book.update(name: "Calliou")
      end

      after do
        conn.drop_temporal_table(:books)
      end

      def author_v = Author::Version.sole

      it "target is instances of Book::Version" do
        expect(author_v.books).to all(be_an_instance_of(Book::Version))
      end

      it "scopes target to extant versions" do
        expect(author_v.books.sole.name).to eq("Calliou")

        Book.sole.destroy

        expect(author_v.books.count).to eq(0)
      end
    end
  end
end
