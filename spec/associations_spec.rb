require "spec_helper"

RSpec.describe "associations" do
  def skip_books_temporal_table = false
  def skip_authors_temporal_table = false
  def skip_libraries_temporal_table = false

  def t(n)
    @timestamps ||= []
    @timestamps[n] ||= Time.current
  end

  def respond_to_missing?(m, include_private = false)
    m.match?(/t_(\d+)/) || super
  end

  def method_missing(m, *args, &block)
    if match = m.match(/t_(\d+)/)
      send(:t, match[1].to_i)
    else
      super
    end
  end

  RSpec::Matchers.define :have_loaded do |assoc|
    match do |record|
      record.send(assoc).loaded?
    end

    failure_message do |record|
      "expected #{record.inspect} to  have :#{assoc} loaded"
    end
  end

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
      # t3 author_v1 <- book_v1, library_v1
      # t4 author_v1 <- book_v2 -> library_v1
      # t5 author_v2 <- book_v2 -> library_v1
      # t5 author_v2 <- book_v3 -> library_v1
      # t5 author_v2 <- book_v3 -> library_v2

      t_0; author = Author.create(name: "Bob")
      t_1; book = Book.create(name: "Calliou", author: author)
      t_2; library = Library.create(name: "Biblio")
      t_3; book.update(library: library)
      t_4; author.update(name: "Bob 2")
      t_5; book.update(name: "Calliou 2")
      t_6; library.update(name: "Biblio 2")
      t_7
    end


    after do
      conn.truncate(:authors)
      conn.truncate(:books)
      conn.truncate(:libraries)

      conn.truncate(:authors_versions) if conn.table_exists?(:authors_versions)
      conn.truncate(:books_versions) if conn.table_exists?(:books_versions)
      conn.truncate(:libraries_versions) if conn.table_exists?(:libraries_versions)
    end
  end 

  shared_context "db" do
    before(:context) do
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
    end

    after(:context) do
      conn.drop_temporal_table(:books) if conn.table_exists?(:books_versions)
      conn.drop_temporal_table(:authors) if conn.table_exists?(:authors_versions)
      conn.drop_temporal_table(:libraries) if conn.table_exists?(:libraries_versions)

      conn.drop_table(:books)
      conn.drop_table(:authors)
      conn.drop_table(:libraries)
    end

    before do
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
  end

  describe "has_many :books" do
    include_context "db"
    include_context "scenario"

    it "scopes books to end of author's validity" do
      expect(author_v1.books).to contain_exactly(book_v2)
      expect(author_v2.books).to contain_exactly(book_v3)
    end

    it "does not set as-of value on books" do
      expect(author_v1.books).to all(have_attrs(as_of_value: be_nil))
      expect(author_v2.books).to all(have_attrs(as_of_value: be_nil))
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
        Author.has_many :calliou_books, -> { where("name ILIKE 'Calliou%'") }, class_name: "Book"
        Author::Version.reversionify

        Book.create(author: Author.sole, name: "Not Calliou")

        expect(author_v1.calliou_books.sole.name).to eq("Calliou")
        expect(author_v2.calliou_books.sole.name).to eq("Calliou 2")
      end
    end

    describe "existing instance-dependent scopes" do
      it "both are applied" do
        Author.has_many :self_titled_books, ->(o) { where(name: o.name) }, class_name: "Book"
        Author::Version.reversionify

        Book.create(author: Author.sole, name: "Bob")
        Book.create(author: Author.sole, name: "Bob 2")

        expect(author_v1.self_titled_books.size).to eq(0)
        expect(author_v2.self_titled_books.sole.name).to eq("Bob 2")
      end
    end

    shared_examples "eager loading books" do
      it "scopes by validity" do
        expect(authors).to all(have_loaded(:books))
        expect(authors).to contain_exactly(
          eq(author_v1).and(have_attrs(books: [book_v2])),
          eq(author_v2).and(have_attrs(books: [book_v3]))
        )
      end

      it "scopes by as-of" do
        expect(authors.as_of(t_1)).to contain_exactly(eq(author_v1)
          .and(have_loaded(:books))
          .and(have_attrs(books: be_empty))
        )
        expect(authors.as_of(t_2)).to contain_exactly(eq(author_v1)
          .and(have_loaded(:books))
          .and(have_attrs(books: [book_v1]))
        )
        expect(authors.as_of(t_6)).to contain_exactly(eq(author_v2)
          .and(have_loaded(:books))
          .and(have_attrs(books: [book_v3]))
        )
      end

      it "sets as-of value on books" do
        expect(authors.as_of(t_1))
          .to all(have_attrs(books: all(have_attrs(as_of_value: t_1))))
        expect(authors.as_of(t_2))
          .to all(have_attrs(books: all(have_attrs(as_of_value: t_2))))
        expect(authors.as_of(t_6))
          .to all(have_attrs(books: all(have_attrs(as_of_value: t_6))))
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

  describe "has_many :books (without books temporal table)" do
    def skip_books_temporal_table = true

    include_context "db"
    include_context "scenario"

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
      it "scopes by validity" do
        expect(authors).to contain_exactly(
          eq(author_v1)
            .and(have_loaded(:books))
            .and(have_attrs(books: [book_v])),
          eq(author_v2)
            .and(have_loaded(:books))
            .and(have_attrs(books: [book_v]))
        )
      end

      it "scopes by as-of" do
        expect(authors.as_of(t_1)).to contain_exactly(eq(author_v1)
          .and(have_loaded(:books))
          .and(have_attrs(books: [book_v]))
        )
        expect(authors.as_of(t_2)).to contain_exactly(eq(author_v1)
          .and(have_loaded(:books))
          .and(have_attrs(books: [book_v]))
        )
        expect(authors.as_of(t_6)).to contain_exactly(eq(author_v2)
          .and(have_loaded(:books))
          .and(have_attrs(books: [book_v]))
        )
      end

      it "sets as-of value on books" do
        expect(authors.as_of(t_1))
          .to all(have_attrs(books: all(have_attrs(as_of_value: t_1))))
        expect(authors.as_of(t_2))
          .to all(have_attrs(books: all(have_attrs(as_of_value: t_2))))
        expect(authors.as_of(t_6))
          .to all(have_attrs(books: all(have_attrs(as_of_value: t_6))))
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

  describe "has_many :books (without authors temporal table)" do
    def skip_authors_temporal_table = true

    include_context "db"
    include_context "scenario"

    it "scopes books to present" do
      expect(author_v.books).to contain_exactly(book_v3)
    end

    it "does not set as-of value on books" do
      expect(author_v.books).to all(have_attrs(as_of_value: be_nil))
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
      it "scopes by validity" do
        expect(authors).to contain_exactly(
          eq(author_v)
            .and(have_loaded(:books))
            .and(have_attrs(books: [book_v3]))
        )
      end

      it "scopes by as-of" do
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

      it "sets as-of value on books" do
        expect(authors.as_of(t_2))
          .to all(have_attrs(books: all(have_attrs(as_of_value: t_2))))
        expect(authors.as_of(t_4))
          .to all(have_attrs(books: all(have_attrs(as_of_value: t_4))))
        expect(authors.as_of(t_6))
          .to all(have_attrs(books: all(have_attrs(as_of_value: t_6))))
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

  describe "has_many :libraries, through: :books" do
    include_context "db"
    include_context "scenario"

    it "scopes libraries to end of author's validity" do
      expect(author_v1.libraries).to contain_exactly(library_v1)
      expect(author_v2.libraries).to contain_exactly(library_v2)
    end

    it "does not set as-of value on libraries" do
      expect(author_v1.libraries).to all(have_attrs(as_of_value: be_nil))
      expect(author_v2.libraries).to all(have_attrs(as_of_value: be_nil))
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
      it "scopes by validity" do
        expect(authors).to all(have_loaded(:libraries))
        expect(authors).to contain_exactly(
          eq(author_v1).and(have_attrs(libraries: [library_v1])),
          eq(author_v2).and(have_attrs(libraries: [library_v2]))
        )
      end

      it "scopes by as-of" do
        expect(authors.as_of(t_1)).to contain_exactly(eq(author_v1)
          .and(have_loaded(:libraries))
          .and(have_attrs(libraries: be_empty))
        )
        expect(authors.as_of(t_3)).to contain_exactly(eq(author_v1)
          .and(have_loaded(:libraries))
          .and(have_attrs(libraries: be_empty))
        )
        expect(authors.as_of(t_4)).to contain_exactly(eq(author_v1)
          .and(have_loaded(:libraries))
          .and(have_attrs(libraries: [library_v1]))
        )
        expect(authors.as_of(t_7)).to contain_exactly(eq(author_v2)
          .and(have_loaded(:libraries))
          .and(have_attrs(libraries: [library_v2]))
        )
      end

      it "sets as-of value on libraries" do
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

    describe "::preload" do
      let(:authors) { Author::Version.preload(:libraries) }

      include_examples "eager loading libraries"
    end
    
    describe "::eager_load" do
      let(:authors) { Author::Version.eager_load(:libraries) }

      include_examples "eager loading libraries"
    end
  end

  describe "has_many :libraries, through: :books (without books temporal table)" do
    def skip_books_temporal_table = true

    include_context "db"
    include_context "scenario"

    it "scopes libraries to end of author's validity" do
      expect(author_v1.libraries).to contain_exactly(library_v2)
      expect(author_v2.libraries).to contain_exactly(library_v2)
    end

    it "does not set as-of value on libraries" do
      expect(author_v1.libraries).to all(have_attrs(as_of_value: be_nil))
      expect(author_v2.libraries).to all(have_attrs(as_of_value: be_nil))
    end

    describe "#as_of" do
      # t0:           <- book_v -> ?
      # t1: author_v1 <- book_v -> ?
      # t2: author_v1 <- book_v -> ?
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
      it "scopes by validity" do
        expect(authors).to contain_exactly(
          eq(author_v1)
            .and(have_loaded(:libraries))
            .and(have_attrs(libraries: [library_v2])),
          eq(author_v2)
            .and(have_loaded(:libraries))
            .and(have_attrs(libraries: [library_v2]))
        )
      end

      it "scopes by as-of" do
        expect(authors.as_of(t_1)).to contain_exactly(eq(author_v1)
          .and(have_loaded(:libraries))
          .and(have_attrs(libraries: be_empty))
        )
        expect(authors.as_of(t_3)).to contain_exactly(eq(author_v1)
          .and(have_loaded(:libraries))
          .and(have_attrs(libraries: [library_v1]))
        )
        expect(authors.as_of(t_4)).to contain_exactly(eq(author_v1)
          .and(have_loaded(:libraries))
          .and(have_attrs(libraries: [library_v1]))
        )
      end

      it "sets as-of value on libraries" do
        expect(authors.as_of(t_1))
          .to all(have_attrs(libraries: all(have_attrs(as_of_value: t_1))))
        expect(authors.as_of(t_3))
          .to all(have_attrs(libraries: all(have_attrs(as_of_value: t_3))))
        expect(authors.as_of(t_4))
          .to all(have_attrs(libraries: all(have_attrs(as_of_value: t_4))))
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

  describe "has_many :employees, through: :libraries" do
    include_context "db"
    include_context "scenario"

    before(:context) do
      conn.create_table(:employees) do |t|
        t.string :name
        t.references :library
      end

      conn.create_temporal_table(:employees)
    end

    after(:context) do
      conn.drop_temporal_table(:employees) if conn.table_exists?(:employees_versions)

      conn.drop_table(:employees)
    end

    before do
      stub_const("Author", Class.new(ActiveRecord::Base) do
        has_many :books
        has_many :libraries, through: :books
        has_many :employees, through: :libraries
      end)
      stub_const("Library", Class.new(ActiveRecord::Base) do
        has_many :books
        has_many :employees
      end)
      stub_const("Employee", Class.new(ActiveRecord::Base) do
        belongs_to :library
      end)

      stub_const("Author::Version", Class.new(Author) { include StrataTables::Model })
      stub_const("Library::Version", Class.new(Library) { include StrataTables::Model })
      stub_const("Employee::Version", Class.new(Employee) { include StrataTables::Model })

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


      t_7; employee = Employee.create!(name: "Sam")
      t_8; employee.update!(library: Library.sole)
      t_9
    end

    let(:employee_v1) { Employee::Version.first }
    let(:employee_v2) { Employee::Version.second }

    after do
      conn.truncate(:employees)

      conn.truncate(:employees_versions) if conn.table_exists?(:employees_versions)
    end

    it "scopes employees to end of author's validity" do
      expect(author_v1.employees).to be_empty
      expect(author_v2.employees).to contain_exactly(employee_v2)
    end

    shared_examples "eager loading employees" do
      it "scopes by validity" do
        expect(authors).to all(have_loaded(:employees))
        expect(authors).to contain_exactly(
          eq(author_v1).and(have_attrs(employees: be_empty)),
          eq(author_v2).and(have_attrs(employees: [employee_v2]))
        )
      end

      it "scopes by as-of" do
        expect(authors.as_of(t_4)).to contain_exactly(eq(author_v1)
          .and(have_loaded(:employees))
          .and(have_attrs(employees: be_empty))
        )
        expect(authors.as_of(t_5)).to contain_exactly(eq(author_v2)
          .and(have_loaded(:employees))
          .and(have_attrs(employees: be_empty))
        )
        expect(authors.as_of(t_7)).to contain_exactly(eq(author_v2)
          .and(have_loaded(:employees))
          .and(have_attrs(employees: be_empty))
        )
        expect(authors.as_of(t_8)).to contain_exactly(eq(author_v2)
          .and(have_loaded(:employees))
          .and(have_attrs(employees: be_empty))
        )
        expect(authors.as_of(t_9)).to contain_exactly(eq(author_v2)
          .and(have_loaded(:employees))
          .and(have_attrs(employees: [employee_v2]))
        )
      end

      it "sets as-of value on employees" do
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

    describe "::preload" do
      let(:authors) { Author::Version.preload(:employees) }

      include_examples "eager loading employees"
    end

    describe "::eager_load" do
      let(:authors) { Author::Version.eager_load(:employees) }

      include_examples "eager loading employees"
    end

    context "without books temporal table" do
      def skip_books_temporal_table = true

      before(:context) do
        conn.drop_temporal_table(:books)
      end

      after(:context) do
        conn.create_temporal_table(:books)
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

      it "scopes employees to end of author's validity" do
        debugger

        expect(author_v1.employees).to contain_exactly(employee_v2)
        expect(author_v2.employees).to contain_exactly(employee_v2)
      end

      shared_examples "eager loading employees" do
        it "scopes by validity" do
          expect(authors).to all(have_loaded(:employees))
          expect(authors).to contain_exactly(
            eq(author_v1).and(have_attrs(employees: [employee_v2])),
            eq(author_v2).and(have_attrs(employees: [employee_v2]))
          )
        end

        it "scopes by as-of" do
          expect(authors.as_of(t_4)).to contain_exactly(eq(author_v1)
            .and(have_loaded(:employees))
            .and(have_attrs(employees: [employee_v2]))
          )
          expect(authors.as_of(t_8)).to contain_exactly(eq(author_v2)
            .and(have_loaded(:employees))
            .and(have_attrs(employees: [employee_v2]))
          )
          expect(authors.as_of(t_9)).to contain_exactly(eq(author_v2)
            .and(have_loaded(:employees))
            .and(have_attrs(employees: [employee_v2]))
          )
        end

        it "sets as-of value on employees" do
          expect(authors.as_of(t_4))
            .to all(have_attrs(employees: all(have_attrs(as_of_value: t_4))))
          expect(authors.as_of(t_8))
            .to all(have_attrs(employees: all(have_attrs(as_of_value: t_8))))
          expect(authors.as_of(t_9))
            .to all(have_attrs(employees: all(have_attrs(as_of_value: t_9))))
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

    context "without libraries temporal table" do
      def skip_libraries_temporal_table = true

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

      it "scopes employees to end of author's validity" do
        expect(author_v1.employees).to contain_exactly(employee_v2)
        expect(author_v2.employees).to contain_exactly(employee_v2)
      end

      shared_examples "eager loading employees" do
        it "scopes by validity" do
          expect(authors).to all(have_loaded(:employees))
          expect(authors).to contain_exactly(
            eq(author_v1).and(have_attrs(employees: [employee_v2])),
            eq(author_v2).and(have_attrs(employees: [employee_v2]))
          )
        end

        it "scopes by as-of" do
          expect(authors.as_of(t_1)).to contain_exactly(eq(author_v1)
            .and(have_loaded(:employees))
            .and(have_attrs(employees: be_empty))
          )
          expect(authors.as_of(t_3)).to contain_exactly(eq(author_v1)
            .and(have_loaded(:employees))
            .and(have_attrs(employees: be_empty))
          )
          expect(authors.as_of(t_4)).to contain_exactly(eq(author_v1)
            .and(have_loaded(:employees))
            .and(have_attrs(employees: [employee_v2]))
          )
          expect(authors.as_of(t_8)).to contain_exactly(eq(author_v2)
            .and(have_loaded(:employees))
            .and(have_attrs(employees: [employee_v2]))
          )
        end

        it "sets as-of value on employees" do
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
end
