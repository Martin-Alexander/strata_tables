require "spec_helper"

RSpec.describe ActiveRecord::Relation, "#as_of" do
  before do
    conn.create_table(:authors) do |t|
      t.string :name
    end
    conn.create_table(:books) do |t|
      t.string :name
      t.references :author
    end
    conn.create_temporal_table(:authors) unless skip_authors_temporal_table
    conn.create_temporal_table(:books) unless skip_books_temporal_table

    stub_const("Author", Class.new(ActiveRecord::Base) do
      has_many :books
    end)
    stub_const("Book", Class.new(ActiveRecord::Base) do
      belongs_to :author
    end)
    stub_const("Author::Version", Class.new(Author) { include StrataTables::Model })
    stub_const("Book::Version", Class.new(Book) { include StrataTables::Model })

    @t0 = Time.current

    author = Author.create(name: "Bob")

    @t1 = Time.current

    Book.create(author: author, name: "Calliou")

    @t2 = Time.current

    Book.create(author: author, name: "Green Eggs")

    @t3 = Time.current
  end

  after do
    conn.drop_table(:authors)
    conn.drop_table(:books)
    conn.drop_temporal_table(:authors) unless skip_authors_temporal_table
    conn.drop_temporal_table(:books) unless skip_books_temporal_table
  end

  let(:skip_authors_temporal_table) { false }
  let(:skip_books_temporal_table) { false }
  
  context "given .all" do
    let(:relation) { Author::Version.all }

    it "filters by validity" do
      expect(relation.as_of(@t0).count).to eq(0)
      expect(relation.as_of(@t1).count).to eq(1)
    end

    it "returns records with as_of set" do
      expect(relation.as_of(@t3).first._as_of).to eq(@t3)
    end

    context "when the table is not a temporal table" do
      let(:relation) { Author.all }

      it "does not filter by validity" do
        expect(relation.as_of(@t0).count).to eq(1)
        expect(relation.as_of(@t1).count).to eq(1)
      end
    end

    context "when called with nil" do
      it "does not filter by validity" do
        expect(relation.count).to eq(1)
      end
    end
  end

  context "given .joins(:books)" do
    let(:relation) { Author::Version.joins(:books) }

    it "filters association by validity" do
      expect(relation.as_of(@t1).count).to eq(0)
      expect(relation.as_of(@t2).count).to eq(1)
    end

    it "returns records with as_of set" do
      expect(relation.as_of(@t3).first._as_of).to eq(@t3)
    end

    context "when called with nil" do
      it "does not filter by validity" do
        expect(relation.count).to eq(2)
      end
    end

    context "when the association has a scope" do
      before do
        Author.has_many :books, -> { where(name: "Green Eggs") }
        Author::Version.reversionify
      end

      it "filters association by validity in addition to scope" do
        expect(relation.as_of(@t1).count).to eq(0)
        expect(relation.as_of(@t2).count).to eq(0)
        expect(relation.as_of(@t3).count).to eq(1)
      end
    end

    context "when the base table is not a temporal table" do
      let(:skip_authors_temporal_table) { true }

      it "still filters association by validity" do
        expect(relation.as_of(@t1).count).to eq(0)
        expect(relation.as_of(@t2).count).to eq(1)
      end
    end

    context "when the associated table is not a temporal table" do
      let(:skip_books_temporal_table) { true }

      it "does not filter association by validity" do
        expect(relation.as_of(@t1).count).to eq(2)
        expect(relation.as_of(@t2).count).to eq(2)
      end
    end
  end

  join_sql = <<~SQL.squish
    JOIN books_versions as bv ON bv.author_id = authors_versions.id
  SQL

  context "given .joins(\"#{join_sql}\")" do
    let(:relation) { Author::Version.joins(join_sql) }

    it "does not filter association by validity" do
      expect(relation.as_of(@t1).count).to eq(2)
      expect(relation.as_of(@t2).count).to eq(2)
    end
  end

  context "given .eager_load(:books)" do
    let(:relation) { Author::Version.eager_load(:books) }

    it "filters associated eager loaded records by validity" do
      expect(relation.as_of(@t1).first.books.size).to eq(0)
      expect(relation.as_of(@t2).first.books.size).to eq(1)
    end
  end

  context "given .includes(:books).joins(\"#{join_sql}\").references(:books)" do
    let(:relation) do
      Author::Version.includes(:books).joins(join_sql).references(:books)
    end

    it "filters associated eager loaded records by validity" do
      expect(relation.as_of(@t1).first.books.size).to eq(0)
      expect(relation.as_of(@t2).first.books.size).to eq(1)
    end
  end

  context "given .preload(:books)" do
    let(:relation) { Author::Version.preload(:books) }

    it "filters associated eager loaded records by validity" do
      expect(relation.as_of(@t1).first.books.size).to eq(0)
      expect(relation.as_of(@t2).first.books.size).to eq(1)
    end
  end
end
