require "spec_helper"

RSpec.describe "associations" do
  shared_context "scenario" do
    let(:author_v1) { Author::Version.first }
    let(:author_v2) { Author::Version.second }
    let(:author_v) { Author::Version.sole }

    let(:book_v1) { Book::Version.first }
    let(:book_v2) { Book::Version.second }
    let(:book_v3) { Book::Version.third }
    let(:book_v) { Book::Version.sole }

    let(:library_v1) { Library::Version.first }
    let(:library_v2) { Library::Version.second }
    let(:library_v) { Library::Version.sole }

    before do
      # t0
      # t1 author_v1
      # t2 author_v1 <- book_v1
      # t3 author_v1 <- book_v1    library_v1
      # t4 author_v1 <- book_v2 -> library_v1
      # t5 author_v2 <- book_v2 -> library_v1
      # t6 author_v2 <- book_v3 -> library_v1
      # t7 author_v2 <- book_v3 -> library_v2

      t_0
      author = Author.create(name: "Bob")
      t_1
      book = Book.create(name: "Calliou", author: author)
      t_2
      library = Library.create(name: "Biblio")
      t_3
      book.update(library: library)
      t_4
      author.update(name: "Bob 2")
      t_5
      book.update(name: "Calliou 2")
      t_6
      library.update(name: "Biblio 2")
    end

    after do
      conn.truncate(:authors)
      conn.truncate(:books)
      conn.truncate(:libraries)

      conn.truncate(:authors_history) if conn.table_exists?(:authors_history)
      conn.truncate(:books_history) if conn.table_exists?(:books_history)
      conn.truncate(:libraries_history) if conn.table_exists?(:libraries_history)
    end
  end

  shared_context "db" do
    before(:context) do
      conn.create_table(:libraries) do |t|
        t.string :name
      end
      conn.create_table(:authors) do |t|
        t.string :name
        t.references :country
      end
      conn.create_table(:books) do |t|
        t.string :name
        t.references :author
        t.references :library
      end

      conn.create_history_table(:books)
      conn.create_history_table(:authors)
      conn.create_history_table(:libraries)

      randomize_sequences!(:id, :version_id)
    end

    after(:context) do
      conn.drop_history_table(:books) if conn.table_exists?(:books_history)
      conn.drop_history_table(:authors) if conn.table_exists?(:authors_history)
      conn.drop_history_table(:libraries) if conn.table_exists?(:libraries_history)

      conn.drop_table(:books)
      conn.drop_table(:authors)
      conn.drop_table(:libraries)
    end

    before do
      stub_const("ApplicationRecord", Class.new(ActiveRecord::Base) do
        self.abstract_class = true

        include StrataTables::Model
      end)
      stub_const("Library", Class.new(ApplicationRecord) do
        has_many :books
      end)
      stub_const("Author", Class.new(ApplicationRecord) do
        has_many :books
        has_many :libraries, through: :books
      end)
      stub_const("Book", Class.new(ApplicationRecord) do
        belongs_to :author
        belongs_to :library
      end)
    end
  end

  describe "has_many :books" do
    include_context "db"
    include_context "scenario"

    context "without as-of" do
      it "scopes to extant books" do
        expect(author_v1.books).to contain_exactly(book_v3)
        expect(author_v2.books).to contain_exactly(book_v3)
      end

      it "does not tags books with as-of" do
        expect(author_v1.books).to all(have_attrs(as_of_value: be_nil))
        expect(author_v2.books).to all(have_attrs(as_of_value: be_nil))
      end
    end

    describe "#as_of" do
      it "scopes book by time" do
        expect(author_v1.as_of(t_1).books).to be_empty
        expect(author_v1.as_of(t_2).books).to contain_exactly(book_v1)
        expect(author_v1.as_of(t_3).books).to contain_exactly(book_v1)
        expect(author_v1.as_of(t_4).books).to contain_exactly(book_v2)
        expect(author_v2.as_of(t_5).books).to contain_exactly(book_v2)
        expect(author_v2.as_of(t_6).books).to contain_exactly(book_v3)
        expect(author_v2.as_of(t_7).books).to contain_exactly(book_v3)
      end

      it "sets as-of value on books" do
        expect(author_v1.as_of(t_2).books).to all(have_attrs(as_of_value: t_2))
        expect(author_v1.as_of(t_3).books).to all(have_attrs(as_of_value: t_3))
        expect(author_v1.as_of(t_4).books).to all(have_attrs(as_of_value: t_4))
        expect(author_v2.as_of(t_5).books).to all(have_attrs(as_of_value: t_5))
        expect(author_v2.as_of(t_6).books).to all(have_attrs(as_of_value: t_6))
        expect(author_v2.as_of(t_7).books).to all(have_attrs(as_of_value: t_7))
      end
    end

    describe "existing scopes" do
      it "both are applied" do
        Author.has_many :calliou_books, -> { where("name ILIKE '%Calliou%'") }, class_name: "Book"
        Author::Version.reversionify

        Book.create(author: Author.sole, name: "I Love Dogs")

        expect(author_v1.calliou_books).to contain_exactly(book_v3)
        expect(author_v2.calliou_books).to contain_exactly(book_v3)

        expect(author_v1.as_of(t_1).calliou_books).to be_empty
        expect(author_v1.as_of(t_2).calliou_books).to contain_exactly(book_v1)
        expect(author_v1.as_of(t_4).calliou_books).to contain_exactly(book_v2)
        expect(author_v2.as_of(t_6).calliou_books).to contain_exactly(book_v3)
        expect(author_v2.as_of(now).calliou_books).to contain_exactly(book_v3)
      end
    end

    describe "existing instance-dependent scopes" do
      it "both are applied" do
        Author.has_many :self_titled_books, ->(o) { where(name: o.name) }, class_name: "Book"
        Author::Version.reversionify

        new_book_1 = Book.create(author: Author.sole, name: "Bob")
        new_book_2 = Book.create(author: Author.sole, name: "Bob 2")

        new_book_1_v1 = Book::Version.where(id: new_book_1).sole
        new_book_2_v1 = Book::Version.where(id: new_book_2).sole

        expect(author_v1.self_titled_books).to contain_exactly(new_book_1_v1)
        expect(author_v2.self_titled_books).to contain_exactly(new_book_2_v1)

        expect(author_v1.as_of(t_4).self_titled_books).to be_empty
        expect(author_v2.as_of(t_6).self_titled_books).to be_empty
        expect(author_v2.as_of(now).self_titled_books).to contain_exactly(new_book_2_v1)
      end
    end

    shared_examples "eager loading books" do
      context "without as-of" do
        it "scopes by extant" do
          expect(authors).to all(have_loaded(:books))
          expect(authors).to contain_exactly(
            eq(author_v1).and(have_attrs(books: [book_v3])),
            eq(author_v2).and(have_attrs(books: [book_v3]))
          )
        end
      end

      context "with as-of" do
        it "scopes books by time" do
          expect(authors.as_of(t_1)).to contain_exactly(eq(author_v1)
            .and(have_loaded(:books))
            .and(have_attrs(books: be_empty)))
          expect(authors.as_of(t_2)).to contain_exactly(eq(author_v1)
            .and(have_loaded(:books))
            .and(have_attrs(books: [book_v1])))
          expect(authors.as_of(t_6)).to contain_exactly(eq(author_v2)
            .and(have_loaded(:books))
            .and(have_attrs(books: [book_v3])))
        end

        it "sets as-of value" do
          expect(authors.as_of(t_1))
            .to all(have_attrs(books: all(have_attrs(as_of_value: t_1))))
          expect(authors.as_of(t_2))
            .to all(have_attrs(books: all(have_attrs(as_of_value: t_2))))
          expect(authors.as_of(t_6))
            .to all(have_attrs(books: all(have_attrs(as_of_value: t_6))))
        end
      end
    end

    describe "::preload" do
      let(:authors) { Author::Version.preload(:books) }

      include_examples "eager loading books"
    end

    describe "::eager_load" do
      let(:authors) { Author::Version.eager_load(:books) }

      include_examples "eager loading books"
    end

    context "without books history table" do
      before(:context) do
        conn.drop_history_table(:books)
      end

      after(:context) do
        conn.create_history_table(:books)
      end

      it "all author versions have the same books" do
        expect(author_v1.books).to contain_exactly(book_v)
        expect(author_v2.books).to contain_exactly(book_v)

        8.times do |n|
          time = t(n)

          expect(author_v1.as_of(time).books).to contain_exactly(book_v)
          expect(author_v1.as_of(time).books).to all(have_attrs(as_of_value: time))

          expect(author_v2.as_of(time).books).to contain_exactly(book_v)
          expect(author_v2.as_of(time).books).to all(have_attrs(as_of_value: time))
        end
      end

      shared_examples "eager loading books" do
        context "without as-of" do
          it "scopes by extant" do
            expect(authors).to contain_exactly(
              eq(author_v1)
                .and(have_loaded(:books))
                .and(have_attrs(books: [book_v])),
              eq(author_v2)
                .and(have_loaded(:books))
                .and(have_attrs(books: [book_v]))
            )
          end
        end

        context "with as-of" do
          it "scopes by time" do
            expect(authors.as_of(t_1)).to contain_exactly(eq(author_v1)
              .and(have_loaded(:books))
              .and(have_attrs(books: [book_v])))
            expect(authors.as_of(t_2)).to contain_exactly(eq(author_v1)
              .and(have_loaded(:books))
              .and(have_attrs(books: [book_v])))
            expect(authors.as_of(t_6)).to contain_exactly(eq(author_v2)
              .and(have_loaded(:books))
              .and(have_attrs(books: [book_v])))
          end

          it "sets as-of value" do
            expect(authors.as_of(t_1))
              .to all(have_attrs(books: all(have_attrs(as_of_value: t_1))))
            expect(authors.as_of(t_2))
              .to all(have_attrs(books: all(have_attrs(as_of_value: t_2))))
            expect(authors.as_of(t_6))
              .to all(have_attrs(books: all(have_attrs(as_of_value: t_6))))
          end
        end
      end

      describe "::preload" do
        let(:authors) { Author::Version.preload(:books) }

        include_examples "eager loading books"
      end

      describe "::eager_load" do
        let(:authors) { Author::Version.eager_load(:books) }

        include_examples "eager loading books"
      end
    end

    context "without authors history table" do
      before(:context) do
        conn.drop_history_table(:authors)
      end

      after(:context) do
        conn.create_history_table(:authors)
      end

      context "without as-of" do
        it "scopes to extant books" do
          expect(author_v.books).to contain_exactly(book_v3)
        end

        it "does not tags books with as-of" do
          expect(author_v.books).to all(have_attrs(as_of_value: be_nil))
        end
      end

      describe "#as_of" do
        it "scopes book by time" do
          expect(author_v.as_of(t_1).books).to be_empty
          expect(author_v.as_of(t_2).books).to contain_exactly(book_v1)
          expect(author_v.as_of(t_3).books).to contain_exactly(book_v1)
          expect(author_v.as_of(t_4).books).to contain_exactly(book_v2)
          expect(author_v.as_of(t_5).books).to contain_exactly(book_v2)
          expect(author_v.as_of(t_6).books).to contain_exactly(book_v3)
          expect(author_v.as_of(t_7).books).to contain_exactly(book_v3)
        end

        it "sets as-of value on books" do
          expect(author_v.as_of(t_2).books).to all(have_attrs(as_of_value: t_2))
          expect(author_v.as_of(t_3).books).to all(have_attrs(as_of_value: t_3))
          expect(author_v.as_of(t_4).books).to all(have_attrs(as_of_value: t_4))
          expect(author_v.as_of(t_5).books).to all(have_attrs(as_of_value: t_5))
          expect(author_v.as_of(t_6).books).to all(have_attrs(as_of_value: t_6))
          expect(author_v.as_of(t_7).books).to all(have_attrs(as_of_value: t_7))
        end
      end

      shared_examples "eager loading books" do
        context "without as-of" do
          it "scopes by extant" do
            expect(authors).to contain_exactly(
              eq(author_v)
                .and(have_loaded(:books))
                .and(have_attrs(books: [book_v3]))
            )
          end
        end

        context "with as-of" do
          it "scopes by time" do
            expect(authors.as_of(t_1)).to contain_exactly(
              eq(author_v)
                .and(have_loaded(:books))
                .and(have_attrs(books: be_empty))
            )
            expect(authors.as_of(t_2)).to contain_exactly(
              eq(author_v)
                .and(have_loaded(:books))
                .and(have_attrs(books: [book_v1]))
            )
            expect(authors.as_of(t_4)).to contain_exactly(
              eq(author_v)
                .and(have_loaded(:books))
                .and(have_attrs(books: [book_v2]))
            )
            expect(authors.as_of(t_6)).to contain_exactly(
              eq(author_v)
                .and(have_loaded(:books))
                .and(have_attrs(books: [book_v3]))
            )
          end

          it "sets as-of value" do
            expect(authors.as_of(t_2))
              .to all(have_attrs(books: all(have_attrs(as_of_value: t_2))))
            expect(authors.as_of(t_4))
              .to all(have_attrs(books: all(have_attrs(as_of_value: t_4))))
            expect(authors.as_of(t_6))
              .to all(have_attrs(books: all(have_attrs(as_of_value: t_6))))
          end
        end
      end

      describe "::preload" do
        let(:authors) { Author::Version.preload(:books) }

        include_examples "eager loading books"
      end

      describe "::eager_load" do
        let(:authors) { Author::Version.eager_load(:books) }

        include_examples "eager loading books"
      end
    end
  end

  describe "has_many :libraries, through: :books" do
    include_context "db"
    include_context "scenario"

    context "without as-of" do
      it "scopes to extant libraries" do
        expect(author_v1.libraries).to contain_exactly(library_v2)
        expect(author_v2.libraries).to contain_exactly(library_v2)
      end

      it "does not tags libraries with as-of" do
        expect(author_v1.libraries).to all(have_attrs(as_of_value: be_nil))
        expect(author_v2.libraries).to all(have_attrs(as_of_value: be_nil))
      end
    end

    describe "#as_of" do
      it "scopes book by time" do
        expect(author_v1.as_of(t_1).libraries).to be_empty
        expect(author_v1.as_of(t_2).libraries).to be_empty
        expect(author_v1.as_of(t_3).libraries).to be_empty
        expect(author_v1.as_of(t_4).libraries).to contain_exactly(library_v1)
        expect(author_v2.as_of(t_5).libraries).to contain_exactly(library_v1)
        expect(author_v2.as_of(t_6).libraries).to contain_exactly(library_v1)
        expect(author_v2.as_of(t_7).libraries).to contain_exactly(library_v2)
      end

      it "sets as-of value on libraries" do
        expect(author_v1.as_of(t_4).libraries).to all(have_attrs(as_of_value: t_4))
        expect(author_v2.as_of(t_5).libraries).to all(have_attrs(as_of_value: t_5))
        expect(author_v2.as_of(t_6).libraries).to all(have_attrs(as_of_value: t_6))
        expect(author_v2.as_of(t_7).libraries).to all(have_attrs(as_of_value: t_7))
      end
    end

    shared_examples "eager loading libraries" do
      context "without as-of" do
        it "scopes by extant" do
          expect(authors).to all(have_loaded(:libraries))
          expect(authors).to contain_exactly(
            eq(author_v1).and(have_attrs(libraries: [library_v2])),
            eq(author_v2).and(have_attrs(libraries: [library_v2]))
          )
        end
      end

      context "with as-of" do
        it "scopes by time" do
          expect(authors.as_of(t_1)).to contain_exactly(eq(author_v1)
            .and(have_loaded(:libraries))
            .and(have_attrs(libraries: be_empty)))
          expect(authors.as_of(t_3)).to contain_exactly(eq(author_v1)
            .and(have_loaded(:libraries))
            .and(have_attrs(libraries: be_empty)))
          expect(authors.as_of(t_4)).to contain_exactly(eq(author_v1)
            .and(have_loaded(:libraries))
            .and(have_attrs(libraries: [library_v1])))
          expect(authors.as_of(t_7)).to contain_exactly(eq(author_v2)
            .and(have_loaded(:libraries))
            .and(have_attrs(libraries: [library_v2])))
        end

        it "sets as-of value" do
          expect(authors.as_of(t_1))
            .to all(have_attrs(libraries: all(have_attrs(as_of_value: t_1))))
          expect(authors.as_of(t_3))
            .to all(have_attrs(libraries: all(have_attrs(as_of_value: t_3))))
          expect(authors.as_of(t_4))
            .to all(have_attrs(libraries: all(have_attrs(as_of_value: t_4))))
          expect(authors.as_of(t_7))
            .to all(have_attrs(libraries: all(have_attrs(as_of_value: t_7))))
        end
      end
    end

    describe "::preload" do
      let(:authors) { Author::Version.preload(:libraries) }

      include_examples "eager loading libraries"
    end

    describe "::eager_load" do
      let(:authors) { Author::Version.eager_load(:libraries) }

      include_examples "eager loading libraries"
    end

    context "without books history table" do
      before(:context) do
        conn.drop_history_table(:books)
      end

      after(:context) do
        conn.create_history_table(:books)
      end

      context "without as-of" do
        it "scopes to extant libraries" do
          expect(author_v1.libraries).to contain_exactly(library_v2)
          expect(author_v2.libraries).to contain_exactly(library_v2)
        end

        it "does not tags libraries with as-of" do
          expect(author_v1.libraries).to all(have_attrs(as_of_value: be_nil))
          expect(author_v2.libraries).to all(have_attrs(as_of_value: be_nil))
        end
      end

      describe "#as_of" do
        # t0:           <- book_v ->
        # t1: author_v1 <- book_v ->
        # t2: author_v1 <- book_v ->
        # t3: author_v1 <- book_v -> library_v1
        # t4: author_v1 <- book_v -> library_v1
        # t5: author_v2 <- book_v -> library_v1
        # t5: author_v2 <- book_v -> library_v1
        # t5: author_v2 <- book_v -> library_v2

        it "scopes book by time" do
          expect(author_v1.as_of(t_1).libraries).to be_empty
          expect(author_v1.as_of(t_2).libraries).to be_empty
          expect(author_v1.as_of(t_3).libraries).to contain_exactly(library_v1) # normally not yet associated
          expect(author_v1.as_of(t_4).libraries).to contain_exactly(library_v1)
          expect(author_v2.as_of(t_5).libraries).to contain_exactly(library_v1)
          expect(author_v2.as_of(t_6).libraries).to contain_exactly(library_v1)
          expect(author_v2.as_of(t_7).libraries).to contain_exactly(library_v2)
        end

        it "sets as-of value on libraries" do
          expect(author_v1.as_of(t_3).libraries).to all(have_attrs(as_of_value: t_3))
          expect(author_v1.as_of(t_4).libraries).to all(have_attrs(as_of_value: t_4))
          expect(author_v2.as_of(t_5).libraries).to all(have_attrs(as_of_value: t_5))
          expect(author_v2.as_of(t_6).libraries).to all(have_attrs(as_of_value: t_6))
          expect(author_v2.as_of(t_7).libraries).to all(have_attrs(as_of_value: t_7))
        end
      end

      shared_examples "eager loading libraries" do
        context "without as-of" do
          it "scopes by extant" do
            expect(authors).to contain_exactly(
              eq(author_v1)
                .and(have_loaded(:libraries))
                .and(have_attrs(libraries: [library_v2])),
              eq(author_v2)
                .and(have_loaded(:libraries))
                .and(have_attrs(libraries: [library_v2]))
            )
          end
        end

        context "with as-of" do
          it "scopes by time" do
            expect(authors.as_of(t_1)).to contain_exactly(eq(author_v1)
              .and(have_loaded(:libraries))
              .and(have_attrs(libraries: be_empty)))
            expect(authors.as_of(t_3)).to contain_exactly(eq(author_v1)
              .and(have_loaded(:libraries))
              .and(have_attrs(libraries: [library_v1])))
            expect(authors.as_of(t_4)).to contain_exactly(eq(author_v1)
              .and(have_loaded(:libraries))
              .and(have_attrs(libraries: [library_v1])))
          end

          it "sets as-of value" do
            expect(authors.as_of(t_1))
              .to all(have_attrs(libraries: all(have_attrs(as_of_value: t_1))))
            expect(authors.as_of(t_3))
              .to all(have_attrs(libraries: all(have_attrs(as_of_value: t_3))))
            expect(authors.as_of(t_4))
              .to all(have_attrs(libraries: all(have_attrs(as_of_value: t_4))))
          end
        end
      end

      describe "::preload" do
        let(:authors) { Author::Version.preload(:libraries) }

        include_examples "eager loading libraries"
      end

      describe "::eager_load" do
        let(:authors) { Author::Version.eager_load(:libraries) }

        include_examples "eager loading libraries"
      end
    end
  end

  describe "has_many :employees, through: :libraries" do
    include_context "db"
    include_context "scenario"

    before(:context) do
      conn.create_table(:employees) do |t|
        t.string :name
        t.references :library
      end

      conn.create_history_table(:employees)

      randomize_sequences!(:id, :version_id)
    end

    after(:context) do
      conn.drop_history_table(:employees) if conn.table_exists?(:employees_history)

      conn.drop_table(:employees)
    end

    before do
      stub_const("Author", Class.new(ApplicationRecord) do
        has_many :books
        has_many :libraries, through: :books
        has_many :employees, through: :libraries
      end)
      stub_const("Library", Class.new(ApplicationRecord) do
        has_many :books
        has_many :employees
      end)
      stub_const("Employee", Class.new(ApplicationRecord) do
        belongs_to :library
      end)

      # t0
      # t1 author_v1
      # t2    "      <- book_v1
      # t3    "            "       library_v1
      # t4    "      <- book_v2 ->     "
      # t5 author_v2       "           "
      # t6    "      <- book_v3 ->     "
      # t7    "            "       library_v2
      # t8    "            "           "         employee_v1
      # t9    "            "           "      <- employee_v2

      t_7
      employee = Employee.create!(name: "Sam")
      t_8
      employee.update!(library: Library.sole)
      t_9
    end

    let(:employee_v1) { Employee::Version.first }
    let(:employee_v2) { Employee::Version.second }

    after do
      conn.truncate(:employees)

      conn.truncate(:employees_history) if conn.table_exists?(:employees_history)
    end

    context "without as-of" do
      it "scopes to extant libraries" do
        expect(author_v1.employees).to contain_exactly(employee_v2)
        expect(author_v2.employees).to contain_exactly(employee_v2)
      end

      it "does not tags libraries with as-of" do
        expect(author_v1.libraries).to all(have_attrs(as_of_value: be_nil))
        expect(author_v2.libraries).to all(have_attrs(as_of_value: be_nil))
      end
    end

    shared_examples "eager loading employees" do
      context "without as-of" do
        it "scopes by extant" do
          expect(authors).to all(have_loaded(:employees))
          expect(authors).to contain_exactly(
            eq(author_v1).and(have_attrs(employees: [employee_v2])),
            eq(author_v2).and(have_attrs(employees: [employee_v2]))
          )
        end
      end

      context "with as-of" do
        it "scopes by time" do
          expect(authors.as_of(t_4)).to contain_exactly(eq(author_v1)
            .and(have_loaded(:employees))
            .and(have_attrs(employees: be_empty)))
          expect(authors.as_of(t_5)).to contain_exactly(eq(author_v2)
            .and(have_loaded(:employees))
            .and(have_attrs(employees: be_empty)))
          expect(authors.as_of(t_7)).to contain_exactly(eq(author_v2)
            .and(have_loaded(:employees))
            .and(have_attrs(employees: be_empty)))
          expect(authors.as_of(t_8)).to contain_exactly(eq(author_v2)
            .and(have_loaded(:employees))
            .and(have_attrs(employees: be_empty)))
          expect(authors.as_of(t_9)).to contain_exactly(eq(author_v2)
            .and(have_loaded(:employees))
            .and(have_attrs(employees: [employee_v2])))
        end

        it "sets as-of value" do
          expect(authors.as_of(t_4))
            .to all(have_attrs(employees: all(have_attrs(as_of_value: t_4))))
          expect(authors.as_of(t_5))
            .to all(have_attrs(employees: all(have_attrs(as_of_value: t_5))))
          expect(authors.as_of(t_7))
            .to all(have_attrs(employees: all(have_attrs(as_of_value: t_7))))
          expect(authors.as_of(t_8))
            .to all(have_attrs(employees: all(have_attrs(as_of_value: t_8))))
          expect(authors.as_of(t_9))
            .to all(have_attrs(employees: all(have_attrs(as_of_value: t_9))))
        end
      end
    end

    describe "::preload" do
      let(:authors) { Author::Version.preload(:employees) }

      include_examples "eager loading employees"
    end

    describe "::eager_load" do
      let(:authors) { Author::Version.eager_load(:employees) }

      include_examples "eager loading employees"
    end

    context "without books history table" do
      before(:context) do
        conn.drop_history_table(:books)
      end

      after(:context) do
        conn.create_history_table(:books)
      end

      # t0           <- book_v ->
      # t1 author_v1 <- book_v ->
      # t2 author_v1 <- book_v ->
      # t3 author_v1 <- book_v -> library_v1
      # t4 author_v1 <- book_v -> library_v1
      # t5 author_v2 <- book_v -> library_v1
      # t6 author_v2 <- book_v -> library_v1
      # t7 author_v2 <- book_v -> library_v2
      # t8 author_v2 <- book_v -> library_v2    employee_v1
      # t9 author_v2 <- book_v -> library_v2 <- employee_v2

      context "without as-of" do
        it "scopes to extant employees" do
          expect(author_v1.employees).to contain_exactly(employee_v2)
          expect(author_v2.employees).to contain_exactly(employee_v2)
        end
      end

      shared_examples "eager loading employees" do
        context "without as-of" do
          it "scopes by extant" do
            expect(authors).to all(have_loaded(:employees))
            expect(authors).to contain_exactly(
              eq(author_v1).and(have_attrs(employees: [employee_v2])),
              eq(author_v2).and(have_attrs(employees: [employee_v2]))
            )
          end
        end

        context "with as-of" do
          it "scopes by time" do
            expect(authors.as_of(t_4)).to contain_exactly(eq(author_v1)
              .and(have_loaded(:employees))
              .and(have_attrs(employees: be_empty)))
            expect(authors.as_of(t_8)).to contain_exactly(eq(author_v2)
              .and(have_loaded(:employees))
              .and(have_attrs(employees: be_empty)))
            expect(authors.as_of(t_9)).to contain_exactly(eq(author_v2)
              .and(have_loaded(:employees))
              .and(have_attrs(employees: [employee_v2])))
          end

          it "sets as-of value" do
            expect(authors.as_of(t_4))
              .to all(have_attrs(employees: all(have_attrs(as_of_value: t_4))))
            expect(authors.as_of(t_8))
              .to all(have_attrs(employees: all(have_attrs(as_of_value: t_8))))
            expect(authors.as_of(t_9))
              .to all(have_attrs(employees: all(have_attrs(as_of_value: t_9))))
          end
        end
      end

      describe "::preload" do
        let(:authors) { Author::Version.preload(:employees) }

        include_examples "eager loading employees"
      end

      describe "::eager_load" do
        let(:authors) { Author::Version.eager_load(:employees) }

        include_examples "eager loading employees"
      end
    end

    context "without libraries history table" do
      before(:context) do
        conn.drop_history_table(:libraries)
      end

      after(:context) do
        conn.create_history_table(:libraries)
      end

      # t0                         library_v
      # t1 author_v1               library_v
      # t2 author_v1 <- book_v1    library_v
      # t3 author_v1 <- book_v1    library_v
      # t4 author_v1 <- book_v2 -> library_v
      # t5 author_v2 <- book_v2 -> library_v
      # t6 author_v2 <- book_v3 -> library_v
      # t7 author_v2 <- book_v3 -> library_v
      # t8 author_v2 <- book_v3 -> library_v    employee_v1
      # t9 author_v2 <- book_v3 -> library_v <- employee_v2

      context "without as-of" do
        it "scopes to extant employees" do
          expect(author_v1.employees).to contain_exactly(employee_v2)
          expect(author_v2.employees).to contain_exactly(employee_v2)
        end
      end

      shared_examples "eager loading employees" do
        context "without as-of" do
          it "scopes by extant" do
            expect(authors).to all(have_loaded(:employees))
            expect(authors).to contain_exactly(
              eq(author_v1).and(have_attrs(employees: [employee_v2])),
              eq(author_v2).and(have_attrs(employees: [employee_v2]))
            )
          end
        end

        context "with as-of" do
          it "scopes by time" do
            expect(authors.as_of(t_1)).to contain_exactly(eq(author_v1)
              .and(have_loaded(:employees))
              .and(have_attrs(employees: be_empty)))
            expect(authors.as_of(t_3)).to contain_exactly(eq(author_v1)
              .and(have_loaded(:employees))
              .and(have_attrs(employees: be_empty)))
            expect(authors.as_of(t_4)).to contain_exactly(eq(author_v1)
              .and(have_loaded(:employees))
              .and(have_attrs(employees: be_empty)))
            expect(authors.as_of(t_8)).to contain_exactly(eq(author_v2)
              .and(have_loaded(:employees))
              .and(have_attrs(employees: be_empty)))
            expect(authors.as_of(t_9)).to contain_exactly(eq(author_v2)
              .and(have_loaded(:employees))
              .and(have_attrs(employees: [employee_v2])))
          end

          it "sets as-of value" do
            expect(authors.as_of(t_1))
              .to all(have_attrs(employees: all(have_attrs(as_of_value: t_1))))
            expect(authors.as_of(t_3))
              .to all(have_attrs(employees: all(have_attrs(as_of_value: t_3))))
            expect(authors.as_of(t_4))
              .to all(have_attrs(employees: all(have_attrs(as_of_value: t_4))))
            expect(authors.as_of(t_8))
              .to all(have_attrs(employees: all(have_attrs(as_of_value: t_8))))
          end
        end
      end

      describe "::preload" do
        let(:authors) { Author::Version.preload(:employees) }

        include_examples "eager loading employees"
      end

      describe "::eager_load" do
        let(:authors) { Author::Version.eager_load(:employees) }

        include_examples "eager loading employees"
      end
    end
  end

  describe "belongs_to :author" do
    include_context "db"
    include_context "scenario"

    context "without as-of" do
      it "scopes to extant authors" do
        expect(book_v1.author).to eq(author_v2)
        expect(book_v2.author).to eq(author_v2)
        expect(book_v3.author).to eq(author_v2)
      end

      it "does not tags books with as-of" do
        expect(book_v1.author.as_of_value).to be_nil
      end
    end

    describe "#as_of" do
      it "scopes author by time" do
        expect(book_v1.as_of(t_3).author).to eq(author_v1)
        expect(book_v2.as_of(t_4).author).to eq(author_v1)
        expect(book_v2.as_of(t_5).author).to eq(author_v2)
        expect(book_v3.as_of(t_6).author).to eq(author_v2)
      end

      it "sets as-of value on author" do
        expect(book_v2.as_of(t_3).author.as_of_value).to eq(t_3)
        expect(book_v2.as_of(t_4).author.as_of_value).to eq(t_4)
        expect(book_v2.as_of(t_5).author.as_of_value).to eq(t_5)
        expect(book_v3.as_of(t_6).author.as_of_value).to eq(t_6)
      end
    end

    shared_examples "eager loading author" do
      context "without as-of" do
        it "scopes by extant" do
          expect(books).to contain_exactly(
            eq(book_v1)
              .and(have_loaded(:author))
              .and(have_attrs(author: author_v2)),
            eq(book_v2)
              .and(have_loaded(:author))
              .and(have_attrs(author: author_v2)),
            eq(book_v3)
              .and(have_loaded(:author))
              .and(have_attrs(author: author_v2))
          )
        end
      end

      context "with as-of" do
        it "scopes author by time" do
          expect(books.as_of(t_3)).to contain_exactly(eq(book_v1)
            .and(have_loaded(:author))
            .and(have_attrs(author: author_v1)))
          expect(books.as_of(t_4)).to contain_exactly(eq(book_v2)
            .and(have_loaded(:author))
            .and(have_attrs(author: author_v1)))
          expect(books.as_of(t_5)).to contain_exactly(eq(book_v2)
            .and(have_loaded(:author))
            .and(have_attrs(author: author_v2)))
          expect(books.as_of(t_6)).to contain_exactly(eq(book_v3)
            .and(have_loaded(:author))
            .and(have_attrs(author: author_v2)))
        end

        it "sets as-of value" do
          expect(books.as_of(t_3))
            .to all(have_attrs(author: have_attrs(as_of_value: t_3)))
          expect(books.as_of(t_4))
            .to all(have_attrs(author: have_attrs(as_of_value: t_4)))
          expect(books.as_of(t_5))
            .to all(have_attrs(author: have_attrs(as_of_value: t_5)))
          expect(books.as_of(t_6))
            .to all(have_attrs(author: have_attrs(as_of_value: t_6)))
        end
      end
    end

    describe "::preload" do
      let(:books) { Book::Version.preload(:author) }

      include_examples "eager loading author"
    end

    describe "::eager_load" do
      let(:books) { Book::Version.eager_load(:author) }

      include_examples "eager loading author"
    end
  end

  shared_context "polymorphic db" do
    include_context "db"

    before(:context) do
      conn.create_table(:pictures) do |t|
        t.string :name
        t.bigint :imageable_id
        t.string :imageable_type
      end

      conn.create_history_table(:pictures)

      randomize_sequences!(:id, :version_id)
    end

    after(:context) do
      conn.drop_history_table(:pictures) if conn.table_exists?(:pictures_history)

      conn.drop_table(:pictures)
    end
  end

  shared_context "polymorphic scenario" do
    include_context "scenario"

    before do
      stub_const("Picture", Class.new(ApplicationRecord) do
        belongs_to :imageable, polymorphic: true
      end)

      Author.has_many :pictures, as: :imageable
      Book.has_many :pictures, as: :imageable

      Author::Version.reversionify
      Book::Version.reversionify

      t_7
      picture = Picture.create!(name: "Author Pic", imageable: Author.sole)
      t_8
      picture.update!(name: "Book Pic", imageable: Book.sole)
      # t_9
    end

    after do
      conn.truncate(:pictures)

      conn.truncate(:pictures_history) if conn.table_exists?(:pictures_history)
    end

    let(:picture_v1) { Picture::Version.first }
    let(:picture_v2) { Picture::Version.second }
  end

  describe "has_many :pictures, as: :imageable" do
    include_context "polymorphic db"
    include_context "polymorphic scenario"

    context "without as-of" do
      it "scopes to extant pictures" do
        expect(author_v1.pictures).to be_empty
        expect(author_v2.pictures).to be_empty
        expect(book_v1.pictures).to contain_exactly(picture_v2)
        expect(book_v3.pictures).to contain_exactly(picture_v2)
      end

      it "does not tags pictures with as-of" do
        expect(book_v1.pictures).to all(have_attrs(as_of_value: be_nil))
      end
    end

    describe "#as_of" do
      it "scopes pictures by time" do
        expect(author_v2.as_of(t_7).pictures).to be_empty
        expect(author_v2.as_of(t_8).pictures).to contain_exactly(picture_v1)
        expect(author_v2.as_of(t_9).pictures).to be_empty
        expect(book_v3.as_of(t_7).pictures).to be_empty
        expect(book_v3.as_of(t_8).pictures).to be_empty
        expect(book_v3.as_of(t_9).pictures).to contain_exactly(picture_v2)
      end

      it "sets as-of value on pictures" do
        expect(author_v2.as_of(t_8).pictures).to all(have_attrs(as_of_value: t_8))
        expect(book_v3.as_of(t_9).pictures).to all(have_attrs(as_of_value: t_9))
      end
    end

    shared_examples "eager loading books" do
      context "without as-of" do
        it "scopes by extant" do
          expect(authors).to contain_exactly(
            eq(author_v1)
              .and(have_loaded(:pictures))
              .and(have_attrs(pictures: be_empty)),
            eq(author_v2)
              .and(have_loaded(:pictures))
              .and(have_attrs(pictures: be_empty))
          )
        end
      end

      context "with as-of" do
        it "scopes pictures by time" do
          expect(authors.as_of(t_2)).to contain_exactly(
            eq(author_v1)
              .and(have_loaded(:pictures))
              .and(have_attrs(pictures: be_empty))
          )
          expect(authors.as_of(t_7)).to contain_exactly(
            eq(author_v2)
              .and(have_loaded(:pictures))
              .and(have_attrs(pictures: be_empty))
          )
          expect(authors.as_of(t_8)).to contain_exactly(
            eq(author_v2)
              .and(have_loaded(:pictures))
              .and(have_attrs(pictures: [picture_v1]))
          )
          expect(authors.as_of(t_9)).to contain_exactly(
            eq(author_v2)
              .and(have_loaded(:pictures))
              .and(have_attrs(pictures: be_empty))
          )
        end

        it "sets as-of value" do
          expect(authors.as_of(t_7))
            .to all(have_attrs(pictures: all(have_attrs(as_of_value: t_7))))
          expect(authors.as_of(t_8))
            .to all(have_attrs(pictures: all(have_attrs(as_of_value: t_8))))
          expect(authors.as_of(t_9))
            .to all(have_attrs(pictures: all(have_attrs(as_of_value: t_9))))
        end
      end
    end

    describe "::preload" do
      let(:authors) { Author::Version.preload(:pictures) }

      include_examples "eager loading books"
    end

    describe "::eager_load" do
      let(:authors) { Author::Version.eager_load(:pictures) }

      include_examples "eager loading books"
    end
  end

  describe "belongs_to :imageable, polymorphic: true" do
    include_context "polymorphic db"
    include_context "polymorphic scenario"

    context "without as-of" do
      it "scopes to extant imageable" do
        expect(picture_v1.imageable).to eq(author_v2)
        expect(picture_v2.imageable).to eq(book_v3)
      end

      it "does not tags imageable with as-of" do
        expect(picture_v1.imageable.as_of_value).to be_nil
        expect(picture_v2.imageable.as_of_value).to be_nil
      end
    end

    describe "#as_of" do
      it "scopes imageable by time" do
        expect(picture_v1.as_of(t_8).imageable).to eq(author_v2)
        expect(picture_v2.as_of(t_9).imageable).to eq(book_v3)
      end

      it "sets as-of value on imageable" do
        expect(picture_v1.as_of(t_8).imageable.as_of_value).to eq(t_8)
        expect(picture_v2.as_of(t_9).imageable.as_of_value).to eq(t_9)
      end
    end

    describe "::preload" do
      let(:pictures) { Picture::Version.preload(:imageable) }

      context "without as-of" do
        it "scopes by extant" do
          expect(pictures).to contain_exactly(
            eq(picture_v1)
              .and(have_loaded(:imageable))
              .and(have_attrs(imageable: author_v2)),
            eq(picture_v2)
              .and(have_loaded(:imageable))
              .and(have_attrs(imageable: book_v3))
          )
        end
      end

      context "with as-of" do
        it "scopes imageable by time" do
          expect(pictures.as_of(t_8)).to contain_exactly(eq(picture_v1)
            .and(have_loaded(:imageable))
            .and(have_attrs(imageable: author_v2)))
          expect(pictures.as_of(t_9)).to contain_exactly(eq(picture_v2)
            .and(have_loaded(:imageable))
            .and(have_attrs(imageable: book_v3)))
        end

        it "sets as-of value" do
          expect(pictures.as_of(t_7))
            .to all(have_attrs(imageable: have_attrs(as_of_value: be_nil)))
          expect(pictures.as_of(t_8))
            .to all(have_attrs(imageable: have_attrs(as_of_value: t_8).or(have_attrs(as_of_value: be_nil))))
          expect(pictures.as_of(t_9))
            .to all(have_attrs(imageable: have_attrs(as_of_value: t_9).or(have_attrs(as_of_value: be_nil))))
        end
      end
    end

    describe "::eager_load" do
      let(:picture) { Picture::Version.eager_load(:imageable) }

      it "raise ActiveRecord::EagerLoadPolymorphicError" do
        expect { picture.load }.to raise_error(ActiveRecord::EagerLoadPolymorphicError)
      end
    end
  end

  describe "belongs_to :coauthor, class_name: \"Author\"" do
    include_context "db"
    include_context "scenario"

    before(:context) do
      conn.add_reference(:authors, :coauthor, foreign_key: {to_table: :authors})
      conn.add_reference(:authors_history, :coauthor)
      conn.create_history_triggers(:authors)
    end

    after(:context) do
      conn.remove_reference(:authors, :coauthor)
      conn.remove_reference(:authors_history, :coauthor)
      conn.create_history_triggers(:authors)
    end

    before do
      stub_const("Author", Class.new(ApplicationRecord) do
        has_many :books
        has_many :libraries, through: :books
        belongs_to :coauthor, class_name: "Author"
      end)

      Author::Version.reversionify

      Author.create!(name: "Jane", coauthor: author_1)
      t_7
      author_1.update(name: "Bob 3")
      t_8
    end

    let(:author_1) { Author.first }
    let(:author_2_v1) { Author::Version.find_by(name: "Jane") }
    let(:author_1_v3) { Author::Version.find_by(name: "Bob 3") }

    after do
      conn.truncate(:authors)
    end

    context "without as-of" do
      it "scopes coauthor by extant" do
        expect(author_2_v1.coauthor).to eq(author_1_v3)
      end
    end

    context "#as_of" do
      it "scopes coauthor by time" do
        expect(author_2_v1.as_of(t_7).coauthor).to eq(author_v2)
        expect(author_2_v1.as_of(t_8).coauthor).to eq(author_1_v3)
      end
    end
  end
end
