# rubocop:disable Layout/SpaceAroundOperators

require "spec_helper"

RSpec.describe "version model" do
  before do
    table :authors, as_of: true do |t|
      t.string :name
    end
    table :books, as_of: true do |t|
      t.string :name
      t.references :author
    end
    table :libraries do |t|
      t.string :name
    end

    model "Author", as_of: true do
      has_many :books, temporal_association_scope
    end
    model "Book", as_of: true
    model "Library", as_of: true
  end

  after { drop_all_tables }

  t = Time.parse("2000-01-01")

  build_records do
    {
      "Author" => {
        author_bob_v1: {id: 1, name: "Bob", period: t+1...t+3},
        author_bob_v2: {id: 1, name: "Bob", period: t+3...t+5},
        author_bob_v3: {id: 1, name: "Bob", period: t+5...nil},
        author_sam_v1: {id: 2, name: "Sam", period: t+2...t+4},
        author_sam_v2: {id: 2, name: "Sam", period: t+4...t+6},
        author_sam_v3: {id: 2, name: "Sam", period: t+6...nil}
      },
      "Book" => {
        foo_v1: {id: 1, name: "Foo old", author_id: 1, period: t+2...t+4},
        foo_v2: {id: 1, name: "Foo new", author_id: 1, period: t+4...t+7},
        foo_v3: {id: 1, name: "Foo new", author_id: 2, period: t+7...nil}
      },
      "Library" => {
        author_bob: {name: "Bob"},
        author_sam: {name: "Sam"}
      }
    }
  end

  describe "::existed_at" do
    it "scopes to records existing as of given time" do
      expect(Author.existed_at(t+3))
        .to contain_exactly(author_bob_v2, author_sam_v1)
      expect(Author.existed_at(t+5))
        .to contain_exactly(author_bob_v3, author_sam_v2)
      expect(Author.existed_at(t+99))
        .to contain_exactly(author_bob_v3, author_sam_v3)
    end

    context "when column does not exist" do
      it "does not scope" do
        expect(Library.existed_at(t+3)).to eq(Library.all)
        expect(Library.existed_at(t+99)).to eq(Library.all)
      end
    end
  end

  describe "::extant" do
    it "scopes to existing records " do
      expect(Author.extant)
        .to contain_exactly(author_bob_v3, author_sam_v3)
    end

    context "when column does not exist" do
      it "does not scope" do
        expect(Library.extant).to eq(Library.all)
      end
    end
  end

  describe "::as_of" do
    it "scopes by as-of and tags loaded records" do
      time = t+3
      relation = Author.as_of(time)

      expect(relation).to contain_exactly(author_bob_v2, author_sam_v1)
      expect(relation).to all(have_attributes(period_as_of: time))
    end

    context "when column does not exist" do
      it "does not scope but still tags loaded records" do
        time = t+3
        relation = Library.as_of(time)

        expect(Library.as_of(time)).to eq(Library.all)
        expect(relation).to all(have_attributes(period_as_of: time))
      end
    end
  end

  describe "#as_of!" do
    it "tags the record" do
      author_bob_v1.as_of!(t+2)
      author_sam_v3.as_of!(t+9)
      author_bob.as_of!(t-99)
      author_sam.as_of!(t+99)

      expect(author_bob_v1.period_as_of).to eq(t+2)
      expect(author_sam_v3.period_as_of).to eq(t+9)
      expect(author_bob.period_as_of).to eq(t-99)
      expect(author_sam.period_as_of).to eq(t+99)
    end

    it "reloads the record" do
      author_sam_v3.books.to_a

      fail "'books' association not loaded" unless author_sam_v3.books.loaded?

      author_sam_v3.as_of!(t+9)

      expect(author_sam_v3.books).to_not be_loaded
    end

    it "raises an error if the time is outside the record's as-of range" do
      expect { author_bob_v1.as_of!(t+3) }.to raise_error(
        StrataTables::AsOf::RangeError,
        "#{t+3} is outside of 'period' range"
      )

      expect { author_sam_v3.as_of!(t+5) }.to raise_error(
        StrataTables::AsOf::RangeError,
        "#{t+5} is outside of 'period' range"
      )
    end
  end

  describe "#as_of" do
    it "returns a new tagged record" do
      author_bob_v1_tagged = author_bob_v1.as_of(t+2)
      author_sam_v3_tagged = author_sam_v3.as_of(t+9)
      author_bob_tagged = author_bob.as_of(t-99)
      author_sam_tagged = author_sam.as_of(t+99)

      expect(author_bob_v1_tagged.period_as_of).to eq(t+2)
      expect(author_sam_v3_tagged.period_as_of).to eq(t+9)
      expect(author_bob_tagged.period_as_of).to eq(t-99)
      expect(author_sam_tagged.period_as_of).to eq(t+99)
    end

    it "returns nil if the time is outside the record's as-of range" do
      author_bob_v1_tagged = author_bob_v1.as_of(t+3)
      author_sam_v3_tagged = author_sam_v3.as_of(t+5)

      expect(author_bob_v1_tagged).to be_nil
      expect(author_sam_v3_tagged).to be_nil
    end
  end

  describe "::temporal_association_scope" do
    context "without a scope" do
      let(:timeline) do
        {
          nil => [
            [author_bob_v1, {books: []}],
            [author_bob_v2, {books: []}],
            [author_bob_v3, {books: []}],
            [author_sam_v1, {books: [foo_v3]}],
            [author_sam_v2, {books: [foo_v3]}],
            [author_sam_v3, {books: [foo_v3]}]
          ],
          t+1 => [
            [author_bob_v1, {books: []}]
          ],
          t+2 => [
            [author_bob_v1, {books: [foo_v1]}],
            [author_sam_v1, {books: []}]
          ],
          t+3 => [
            [author_bob_v2, {books: [foo_v1]}],
            [author_sam_v1, {books: []}]
          ],
          t+4 => [
            [author_bob_v2, {books: [foo_v2]}],
            [author_sam_v2, {books: []}]
          ],
          t+5 => [
            [author_bob_v3, {books: [foo_v2]}],
            [author_sam_v2, {books: []}]
          ],
          t+6 => [
            [author_bob_v3, {books: [foo_v2]}],
            [author_sam_v3, {books: []}]
          ],
          t+7 => [
            [author_bob_v3, {books: []}],
            [author_sam_v3, {books: [foo_v3]}]
          ]
        }
      end

      describe "#eager_load" do
        test_eager_loading(n_steps: 8) { Author.eager_load(:books) }
      end

      describe "#preload" do
        test_eager_loading(n_steps: 8) { Author.preload(:books) }
      end

      describe "association reader" do
        test_association_reader(n_steps: 8)
      end
    end

    context "given a scope" do
      before do
        Author.class_eval do
          has_many :books,
            temporal_association_scope { where(name: "Foo old") }
        end
      end

      let(:timeline) do
        {
          nil => [
            [author_bob_v1, {books: []}],
            [author_bob_v2, {books: []}],
            [author_bob_v3, {books: []}],
            [author_sam_v1, {books: []}],
            [author_sam_v2, {books: []}],
            [author_sam_v3, {books: []}]
          ],
          t+1 => [
            [author_bob_v1, {books: []}]
          ],
          t+2 => [
            [author_bob_v1, {books: [foo_v1]}],
            [author_sam_v1, {books: []}]
          ],
          t+3 => [
            [author_bob_v2, {books: [foo_v1]}],
            [author_sam_v1, {books: []}]
          ],
          t+4 => [
            [author_bob_v2, {books: []}],
            [author_sam_v2, {books: []}]
          ],
          t+5 => [
            [author_bob_v3, {books: []}],
            [author_sam_v2, {books: []}]
          ],
          t+6 => [
            [author_bob_v3, {books: []}],
            [author_sam_v3, {books: []}]
          ],
          t+7 => [
            [author_bob_v3, {books: []}],
            [author_sam_v3, {books: []}]
          ]
        }
      end

      describe "#eager_load" do
        test_eager_loading(n_steps: 8) { Author.eager_load(:books) }
      end

      describe "#preload" do
        test_eager_loading(n_steps: 8) { Author.preload(:books) }
      end

      describe "association reader" do
        test_association_reader(n_steps: 8)
      end
    end

    context "given an instance-dependent scope" do
      before do
        Author.class_eval do
          has_many :books,
            temporal_association_scope { |owner|
              (owner.name == "Bob") ? where(name: "Foo new") : none
            }
        end
      end

      let(:timeline) do
        {
          nil => [
            [author_bob_v1, {books: []}],
            [author_bob_v2, {books: []}],
            [author_bob_v3, {books: []}],
            [author_sam_v1, {books: []}],
            [author_sam_v2, {books: []}],
            [author_sam_v3, {books: []}]
          ],
          t+1 => [
            [author_bob_v1, {books: []}]
          ],
          t+2 => [
            [author_bob_v1, {books: []}],
            [author_sam_v1, {books: []}]
          ],
          t+3 => [
            [author_bob_v2, {books: []}],
            [author_sam_v1, {books: []}]
          ],
          t+4 => [
            [author_bob_v2, {books: [foo_v2]}],
            [author_sam_v2, {books: []}]
          ],
          t+5 => [
            [author_bob_v3, {books: [foo_v2]}],
            [author_sam_v2, {books: []}]
          ],
          t+6 => [
            [author_bob_v3, {books: [foo_v2]}],
            [author_sam_v3, {books: []}]
          ],
          t+7 => [
            [author_bob_v3, {books: []}],
            [author_sam_v3, {books: []}]
          ]
        }
      end

      it "eager-loading raises an error" do
        expect { Author.as_of(t+3).eager_load(:books).load }
          .to raise_error(ArgumentError, /is instance dependent/)
      end

      describe "#preload" do
        test_eager_loading(n_steps: 8) { Author.preload(:books) }
      end

      describe "association reader" do
        test_association_reader(n_steps: 8)
      end
    end
  end
end

# rubocop:enable Layout/SpaceAroundOperators
