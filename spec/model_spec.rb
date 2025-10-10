require "spec_helper"

RSpec.describe StrataTables::Model do
  before do
    conn.create_table(:libraries) do |t|
      t.string :name
    end
    conn.create_table(:authors) do |t|
      t.string :name
    end
    conn.create_table(:books) do |t|
      t.string :name
      t.references :author
      t.references :library
    end

    conn.create_temporal_table(:books) unless skip_books_temporal_table
    conn.create_temporal_table(:authors) unless skip_authors_temporal_table
    conn.create_temporal_table(:libraries) unless skip_libraries_temporal_table

    stub_const("Library", Class.new(ActiveRecord::Base) do
      has_many :books
    end)
    stub_const("Author", Class.new(ActiveRecord::Base) do
      has_many :books
      has_many :libraries, through: :books
    end)
    stub_const("Book", Class.new(ActiveRecord::Base) do
      belongs_to :author
      belongs_to :library
    end)

    stub_const("Library::Version", Class.new(Library) { include StrataTables::Model })
    stub_const("Author::Version", Class.new(Author) { include StrataTables::Model })
    stub_const("Book::Version", Class.new(Book) { include StrataTables::Model })
  end

  after do
    conn.drop_temporal_table(:books) unless skip_books_temporal_table
    conn.drop_temporal_table(:authors) unless skip_authors_temporal_table
    conn.drop_temporal_table(:libraries) unless skip_libraries_temporal_table

    conn.drop_table(:books)
    conn.drop_table(:authors)
    conn.drop_table(:libraries)
  end

  let(:skip_books_temporal_table) { false }
  let(:skip_authors_temporal_table) { false }
  let(:skip_libraries_temporal_table) { false }

  describe "::table_name" do
    context "when table is temporal" do
      it "returns name of temporal table" do
        expect(Author::Version.table_name).to eq("authors_versions")
      end
    end

    context "when table is non-temporal" do
      let(:skip_authors_temporal_table) { true }

      it "returns name of non-temporal table" do
        expect(Author::Version.table_name).to eq("authors")
      end
    end
  end

  describe "#validity_start", "#validity_end" do
    before do
      author = Author.create(name: "Bob")
      author.update(name: "Bob 2")
    end

    let(:author_v1) { Author::Version.find_by(name: "Bob") }
    let(:author_v2) { Author::Version.find_by(name: "Bob 2") }

    context "when table is temporal" do
      it "returns the data from the DB" do
        expect(author_v1.validity_start).to be_an_instance_of(Time)
        expect(author_v1.validity_end).to be_an_instance_of(Time)

        expect(author_v2.validity_start).to be_an_instance_of(Time)
        expect(author_v2.validity_end).to be_nil
      end
    end

    context "when table is non-temporal" do
      let(:skip_authors_temporal_table) { true }

      it "returns nil and nil" do
        expect(author_v2.validity_start).to be_nil
        expect(author_v2.validity_end).to be_nil
      end
    end
  end

  describe "has_many associations" do
    before do
      @author = Author.create(name: "Bob")
      @t1 = Time.current
      book = Book.create(name: "Calliou", author: @author)
      @t2 = Time.current
      @author.update(name: "Bob 2")
      @t3 = Time.current
      book.update(name: "Calliou 2")
      @t4 = Time.current
    end

    let(:author_v1) { Author::Version.find_by(name: "Bob") }
    let(:author_v2) { Author::Version.find_by(name: "Bob 2") }
    let(:book_v1) { Book::Version.find_by(name: "Calliou") }
    let(:book_v2) { Book::Version.find_by(name: "Calliou 2") }

    it "target is instances of version class" do
      expect(author_v2.books).to all(be_an_instance_of(Book::Version))
    end

    it "scopes target to owner's validity end if as-of value is absent" do
      expect(author_v1.books.sole).to eq(book_v1)
      expect(author_v2.books.sole).to eq(book_v2)
    end

    it "does not set target's as-of value if owner's is absent" do
      expect(author_v1.books.sole.as_of_value).to be_nil
      expect(author_v2.books.sole.as_of_value).to be_nil
    end

    it "scopes target to owner's as-of value if present" do
      expect(author_v1.as_of(@t1).books).to be_empty
      expect(author_v1.as_of(@t2).books.sole).to eq(book_v1)
      expect(author_v2.as_of(@t3).books.sole).to eq(book_v1)
      expect(author_v2.as_of(@t4).books.sole).to eq(book_v2)
    end

    it "sets target's as-of value if owner's value is present" do
      expect(author_v1.as_of(@t2).books.sole.as_of_value).to eq(@t2)
      expect(author_v2.as_of(@t4).books.sole.as_of_value).to eq(@t4)
    end

    describe "existing association scopes" do
      it "applies association scopes from base class" do
        Author.has_many :calliou_books, -> { where("name ILIKE 'Calliou%'") }, class_name: "Book"
        Author::Version.reversionify

        Book.create(author: @author, name: "Not Calliou")

        expect(author_v1.calliou_books.sole.name).to eq("Calliou")
        expect(author_v2.calliou_books.sole.name).to eq("Calliou 2")
      end

      it "applies instance-dependent association scopes from base class" do
        Author.has_many :self_titled_books, ->(o) { where(name: o.name) }, class_name: "Book"
        Author::Version.reversionify

        Book.create(author: @author, name: "Bob")
        Book.create(author: @author, name: "Bob 2")

        expect(author_v1.self_titled_books.size).to eq(0)
        expect(author_v2.self_titled_books.sole.name).to eq("Bob 2")
      end
    end

    def default_scoping(query_method)
      authors = Author::Version.send(query_method, :books).to_a

      expect(authors.size).to eq(2)

      expect(authors.first.books.size).to eq(1)
      expect(authors.first.books.sole)
        .to have_attributes(name: "Calliou", as_of_value: nil)

      expect(authors.last.books.size).to eq(1)
      expect(authors.last.books.sole)
        .to have_attributes(name: "Calliou 2", as_of_value: nil)
    end

    def as_of_scoping(query_method)
      authors = Author::Version.send(query_method, :books).as_of(@t1).to_a

      expect(authors.sole.name).to eq("Bob")
      expect(authors.sole.books.size).to eq(0)

      authors = Author::Version.preload(:books).as_of(@t2).to_a

      expect(authors.sole.name).to eq("Bob")
      expect(authors.sole.books.size).to eq(1)
      expect(authors.sole.books.sole.name).to eq("Calliou")
    end

    def as_of_tagging(query_method)
      authors = Author::Version.send(query_method, :books).as_of(@t2).to_a

      expect(authors.sole.as_of_value).to eq(@t2)
      expect(authors.sole.books.sole.as_of_value).to eq(@t2)
    end

    describe "preloading" do
      it("scopes associations by validity") { default_scoping(:preload) }
      it("scope query by as-of") { as_of_scoping(:preload) }
      it("tags results with as-of value") { as_of_tagging(:preload) }
    end

    describe "eager loading" do
      it("scopes associations by validity") { default_scoping(:eager_load) }
      it("scope query by as-of") { as_of_scoping(:eager_load) }
      it("tags results with as-of value") { as_of_tagging(:eager_load) }
    end

    context "when the target table is non-temporal" do
      let(:skip_books_temporal_table) { true }
      let(:book_v) { Book::Version.sole }

      it "does not scope target if owner's as-of value is absent" do
        expect(author_v1.books.sole).to eq(book_v)
        expect(author_v2.books.sole).to eq(book_v)
      end

      it "does not set target's as-of value if owner's is absent" do
        expect(author_v1.books.sole.as_of_value).to be_nil
        expect(author_v2.books.sole.as_of_value).to be_nil
      end

      it "does not scope target if owner's as-of value if present" do
        expect(author_v1.as_of(@t1).books.sole).to eq(book_v)
        expect(author_v1.as_of(@t2).books.sole).to eq(book_v)
        expect(author_v2.as_of(@t3).books.sole).to eq(book_v)
        expect(author_v2.as_of(@t4).books.sole).to eq(book_v)
      end

      it "sets target's as-of value if owner's value is present" do
        expect(author_v1.as_of(@t2).books.sole.as_of_value).to eq(@t2)
        expect(author_v2.as_of(@t4).books.sole.as_of_value).to eq(@t4)
      end

      def default_scoping(query_method)
        authors = Author::Version.send(query_method, :books).to_a

        expect(authors.size).to eq(2)

        expect(authors.first.books.size).to eq(1)
        expect(authors.first.books.sole)
          .to have_attributes(name: "Calliou 2", as_of_value: nil)

        expect(authors.last.books.size).to eq(1)
        expect(authors.last.books.sole)
          .to have_attributes(name: "Calliou 2", as_of_value: nil)
      end

      def as_of_scoping(query_method)
        authors = Author::Version.send(query_method, :books).as_of(@t1).to_a

        expect(authors.sole.name).to eq("Bob")
        expect(authors.sole.books.size).to eq(1)
        expect(authors.sole.books.sole.name).to eq("Calliou 2")

        authors = Author::Version.send(query_method, :books).as_of(@t2).to_a

        expect(authors.sole.name).to eq("Bob")
        expect(authors.sole.books.size).to eq(1)
        expect(authors.sole.books.sole.name).to eq("Calliou 2")
      end

      def as_of_tagging(query_method)
        authors = Author::Version.send(query_method, :books).as_of(@t2).to_a

        expect(authors.sole.as_of_value).to eq(@t2)
        expect(authors.sole.books.sole.as_of_value).to eq(@t2)
      end

      describe "preloading" do
        it("scopes associations by validity") { default_scoping(:preload) }
        it("scope query by as-of") { as_of_scoping(:preload) }
        it("tags results with as-of value") { as_of_tagging(:preload) }
      end

      describe "eager loading" do
        it("scopes associations by validity") { default_scoping(:eager_load) }
        it("scope query by as-of") { as_of_scoping(:eager_load) }
        it("tags results with as-of value") { as_of_tagging(:eager_load) }
      end
    end

    context "when owner table is non-temporal" do
      let(:skip_authors_temporal_table) { true }
      let(:author_v) { Author::Version.sole }

      it "scopes target to present if owner's as-of value is absent" do
        expect(author_v.books.sole).to eq(book_v2)
      end

      it "does not set target's as-of value if owner's is absent" do
        expect(author_v.books.sole.as_of_value).to be_nil
      end

      it "scopes target to owner's as-of value if present" do
        expect(author_v.as_of(@t1).books).to be_empty
        expect(author_v.as_of(@t2).books.sole).to eq(book_v1)
        expect(author_v.as_of(@t3).books.sole).to eq(book_v1)
        expect(author_v.as_of(@t4).books.sole).to eq(book_v2)
      end

      it "sets target's as-of value if owner's value is present" do
        expect(author_v.as_of(@t2).books.sole.as_of_value).to eq(@t2)
        expect(author_v.as_of(@t4).books.sole.as_of_value).to eq(@t4)
      end

      def default_scoping(query_method)
        authors = Author::Version.send(query_method, :books).to_a

        expect(authors.sole)
          .to have_attributes(name: "Bob 2", as_of_value: nil)
        expect(authors.first.books.size).to eq(1)
        expect(authors.first.books.sole)
          .to have_attributes(name: "Calliou 2", as_of_value: nil)
      end

      def as_of_scoping(query_method)
        authors = Author::Version.send(query_method, :books).as_of(@t1).to_a

        expect(authors.sole.name).to eq("Bob 2")
        expect(authors.sole.books.size).to eq(0)

        authors = Author::Version.send(query_method, :books).as_of(@t2).to_a

        expect(authors.sole.name).to eq("Bob 2")
        expect(authors.sole.books.size).to eq(1)
        expect(authors.sole.books.sole.name).to eq("Calliou")
      end

      def as_of_tagging(query_method)
        authors = Author::Version.send(query_method, :books).as_of(@t2).to_a

        expect(authors.sole.as_of_value).to eq(@t2)
        expect(authors.sole.books.sole.as_of_value).to eq(@t2)
      end

      describe "preloading" do
        it("scopes associations by validity") { default_scoping(:preload) }
        it("scope query by as-of") { as_of_scoping(:preload) }
        it("tags results with as-of value") { as_of_tagging(:preload) }
      end

      describe "eager loading" do
        it("scopes associations by validity") { default_scoping(:eager_load) }
        it("scope query by as-of") { as_of_scoping(:eager_load) }
        it("tags results with as-of value") { as_of_tagging(:eager_load) }
      end
    end
  end

  describe "has_many :though associations" do
    before do
      author = Author.create(name: "Bob")
      @t1 = Time.current
      book = Book.create(name: "Calliou", author: author)
      @t2 = Time.current
      library = Library.create(name: "Biblio")
      @t3 = Time.current
      book.update(library: library)
      @t4 = Time.current
      author.update(name: "Bob 2")
      @t5 = Time.current
      book.update(name: "Calliou 2")
      @t6 = Time.current
      library.update(name: "Biblio 2")
      @t7 = Time.current
    end

    let(:author_v1) { Author::Version.find_by(name: "Bob") }
    let(:author_v2) { Author::Version.find_by(name: "Bob 2") }
    let(:book_v1) { Book::Version.find_by(name: "Calliou") }
    let(:book_v2) { Book::Version.find_by(name: "Calliou 2") }
    let(:library_v1) { Library::Version.find_by(name: "Biblio") }
    let(:library_v2) { Library::Version.find_by(name: "Biblio 2") }

    it "scopes target to owner's validity end if as-of value is absent" do
      expect(author_v1.libraries.sole).to eq(library_v1)
      expect(author_v2.libraries.sole).to eq(library_v2)
    end

    it "scopes target to owner's as-of value if present" do
      expect(author_v1.as_of(@t1).libraries.size).to eq(0)
      expect(author_v1.as_of(@t2).libraries.size).to eq(0)
      expect(author_v1.as_of(@t3).libraries.size).to eq(0)
      expect(author_v1.as_of(@t4).libraries.sole.name).to eq("Biblio")
      expect(author_v2.as_of(@t5).libraries.sole.name).to eq("Biblio")
      expect(author_v2.as_of(@t6).libraries.sole.name).to eq("Biblio")
      expect(author_v2.as_of(@t7).libraries.sole.name).to eq("Biblio 2")
    end

    it "sets target's as-of value if owner's value is present" do
      expect(author_v1.as_of(@t4).libraries.sole.as_of_value).to eq(@t4)
      expect(author_v2.as_of(@t5).libraries.sole.as_of_value).to eq(@t5)
      expect(author_v2.as_of(@t6).libraries.sole.as_of_value).to eq(@t6)
      expect(author_v2.as_of(@t7).libraries.sole.as_of_value).to eq(@t7)
    end

    def default_scoping(query_method)
      authors = Author::Version.send(query_method, :libraries).to_a

      expect(authors.size).to eq(2)

      expect(authors.first.name).to eq("Bob")
      expect(authors.first.books.size).to eq(1)
      expect(authors.first.books.sole)
        .to have_attributes(name: "Calliou", as_of_value: nil)
      expect(authors.first.libraries.size).to eq(1)
      expect(authors.first.libraries.sole)
        .to have_attributes(name: "Biblio", as_of_value: nil)

      expect(authors.last.name).to eq("Bob 2")
      expect(authors.last.books.size).to eq(1)
      expect(authors.last.books.sole)
        .to have_attributes(name: "Calliou 2", as_of_value: nil)
      expect(authors.last.libraries.size).to eq(1)
      expect(authors.last.libraries.sole)
        .to have_attributes(name: "Biblio 2", as_of_value: nil)
    end

    def as_of_scoping(query_method)
      authors = Author::Version.send(query_method, :libraries).as_of(@t1).to_a
      author = authors.sole

      expect(author.name).to eq("Bob")
      expect(author.books.size).to eq(0)
      expect(author.libraries.size).to eq(0)

      authors = Author::Version.send(query_method, :libraries).as_of(@t2).to_a
      author = authors.sole

      expect(author.name).to eq("Bob")
      expect(author.books.size).to eq(1)
      expect(author.books.first.name).to eq("Calliou")
      expect(author.libraries.size).to eq(0)

      authors = Author::Version.send(query_method, :libraries).as_of(@t4).to_a
      author = authors.sole

      expect(author.name).to eq("Bob")
      expect(author.books.size).to eq(1)
      expect(author.books.sole.name).to eq("Calliou")
      expect(author.libraries.size).to eq(1)
      expect(author.libraries.sole.name).to eq("Biblio")
    end

    def as_of_tagging(query_method)
      authors = Author::Version.send(query_method, :libraries).as_of(@t4).to_a

      expect(authors.sole.as_of_value).to eq(@t4)
      expect(authors.sole.books.sole.as_of_value).to eq(@t4)
      expect(authors.sole.libraries.sole.as_of_value).to eq(@t4)
    end

    describe "preloading" do
      it("scopes associations by validity") { default_scoping(:preload) }
      it("scope query by as-of") { as_of_scoping(:preload) }
      it("tags results with as-of value") { as_of_tagging(:preload) }
    end

    describe "eager loading" do
      it("scopes associations by validity") { default_scoping(:eager_load) }
      it("scope query by as-of") { as_of_scoping(:eager_load) }
      it("tags results with as-of value") { as_of_tagging(:eager_load) }
    end

    describe "nested associations" do
      describe "preloading" do
        it "scopes associations by validity" do
          authors = Author::Version.preload(books: :library)

          expect(authors.size).to eq(2)
          expect(authors.first.libraries.size).to eq(1)
          expect(authors.first.libraries.sole)
            .to have_attributes(name: "Biblio", as_of_value: nil)

          expect(authors.last.libraries.size).to eq(1)
          expect(authors.last.libraries.sole)
            .to have_attributes(name: "Biblio 2", as_of_value: nil)
        end

        it "scope query by as-of" do
          authors = Author::Version.preload(books: :library).as_of(@t1).to_a

          expect(authors.sole.name).to eq("Bob")
          expect(authors.sole.libraries.size).to eq(0)

          authors = Author::Version.preload(books: :library).as_of(@t4).to_a

          expect(authors.sole.name).to eq("Bob")
          expect(authors.sole.libraries.size).to eq(1)
          expect(authors.sole.libraries.sole.name).to eq("Biblio")
        end

        it "tags results with as-of value" do
          authors = Author::Version.preload(books: :library).as_of(@t4).to_a

          expect(authors.sole.as_of_value).to eq(@t4)
          expect(authors.sole.libraries.sole.as_of_value).to eq(@t4)
        end
      end
    end
  end
end
