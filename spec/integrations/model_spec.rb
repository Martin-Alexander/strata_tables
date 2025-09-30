require "spec_helper"

RSpec.describe "as_of" do
  def setup_tables(name, &block)
    conn.create_table(name, &block)
    conn.create_temporal_table(name)
  end

  def teardown_tables(name)
    conn.drop_table(name)
    conn.drop_temporal_table(name) if conn.table_exists?("#{name}_versions")
  end

  def setup_model(name, parent_klass = ApplicationRecord, &block)
    klass = Class.new(parent_klass)

    klass.class_eval(&block) if block_given?

    stub_const(name, klass)
  end

  def setup_version_model(model_klass_name, &block)
    model_klass = model_klass_name.constantize

    klass = setup_model("#{model_klass.name}::Version", model_klass) do
      self.table_name = "#{model_klass.table_name}_versions"
    end

    klass.class_eval(&block) if block_given?
  end

  before do
    setup_tables(:authors) do |t|
      t.string :name
    end
    setup_tables(:books) do |t|
      t.string :name
      t.references :author
    end

    setup_model("Author") do
      has_many :books
    end
    setup_version_model("Author") do
      has_many :books, class_name: "Book::Version", foreign_key: :author_id
    end
    setup_model("Book") do
      belongs_to :author
    end
    setup_version_model("Book") do
      belongs_to :author, class_name: "Author::Version"
    end

    author = Author.create(name: "Bob")

    t1

    Book.create(author: author, name: "Calliou")

    t2

    Book.create(author: author, name: "Green Eggs")

    t3
  end

  after do
    teardown_tables(:authors)
    teardown_tables(:books)
  end

  let(:t1) { get_time }
  let(:t2) { get_time }
  let(:t3) { get_time }

  context "given .all" do
    let(:relation) { Book::Version.all }

    it "filters by validity" do
      expect(relation.as_of(t1).count).to eq(0)
      expect(relation.as_of(t2).count).to eq(1)
      expect(relation.as_of(t3).count).to eq(2)
    end

    context "when the table is not a temporal table" do
      before do
        conn.drop_temporal_table(:books)

        setup_model("Book::Version") do
          self.table_name = "books"

          belongs_to :author, class_name: "Author::Version"
        end
      end

      it "does not filter by validity" do
        expect(relation.as_of(t1).count).to eq(2)
        expect(relation.as_of(t2).count).to eq(2)
        expect(relation.as_of(t3).count).to eq(2)
      end
    end
  end

  context "given .joins(:books)" do
    let(:relation) { Author::Version.joins(:books) }

    it "filters association by validity" do
      expect(relation.as_of(t1).count).to eq(0)
      expect(relation.as_of(t2).count).to eq(1)
      expect(relation.as_of(t3).count).to eq(2)
    end

    context "when the association has a scope" do
      before do
        Author::Version.has_many(
          :books,
          -> { where(name: "Green Eggs") },
          class_name: "Book::Version",
          foreign_key: :author_id
        )
      end

      it "filters association by validity in addition to scope" do
        expect(relation.as_of(t1).count).to eq(0)
        expect(relation.as_of(t2).count).to eq(0)
        expect(relation.as_of(t3).count).to eq(1)
      end
    end

    context "when the table is not a temporal table" do
      before do
        conn.drop_temporal_table(:authors)

        setup_model("Author::Version") do
          self.table_name = "authors"

          has_many :books, class_name: "Book::Version", foreign_key: :author_id
        end
      end

      it "filters association by validity" do
        expect(relation.as_of(t1).count).to eq(0)
        expect(relation.as_of(t2).count).to eq(1)
        expect(relation.as_of(t3).count).to eq(2)
      end
    end

    context "when the associated table is not a temporal table" do
      before do
        conn.drop_temporal_table(:books)

        setup_model("Book::Version") do
          self.table_name = "books"

          belongs_to :author, class_name: "Author::Version"
        end
      end

      it "does not filter association by validity" do
        expect(relation.as_of(t1).count).to eq(2)
        expect(relation.as_of(t2).count).to eq(2)
        expect(relation.as_of(t3).count).to eq(2)
      end
    end
  end

  context "given .joins(\"JOIN books_versions ON books_versions.author_id = authors_versions.id\")" do
    let(:relation) do
      Author::Version.joins("JOIN books_versions ON books_versions.author_id = authors_versions.id")
    end

    it "does not filter association by validity" do
      expect(relation.as_of(t1).count).to eq(2)
      expect(relation.as_of(t2).count).to eq(2)
      expect(relation.as_of(t3).count).to eq(2)
    end
  end
end
