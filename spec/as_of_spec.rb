# rubocop:disable Layout/SpaceAroundOperators

require "spec_helper"

RSpec.describe "version model" do
  before do
    conn.create_table :author_versions, primary_key: :v_id do |t|
      t.bigint :b_id
      t.string :name
      t.tstzrange :period, null: false
    end

    conn.create_table :book_versions, primary_key: :v_id do |t|
      t.bigint :b_id
      t.string :name
      t.bigint :author_id
      t.tstzrange :period, null: false
    end

    conn.create_table :authors do |t|
      t.string :name
    end

    model "AuthorVersion" do
      has_many :books,
        primary_key: :b_id,
        foreign_key: :author_id,
        class_name: "BookVersion"
    end

    model "BookVersion"

    stub_const("Author", Class.new(ActiveRecord::Base) do
      include StrataTables::AsOf

      self.as_of_attribute = :period
    end)
  end

  after { drop_all_tables }

  t = Time.parse("2000-01-01")

  {
    "AuthorVersion" => {
      author_bob_v1: {b_id: 1, name: "Bob", period: t+1...t+3},
      author_bob_v2: {b_id: 1, name: "Bob", period: t+3...t+5},
      author_bob_v3: {b_id: 1, name: "Bob", period: t+5...nil},
      author_sam_v1: {b_id: 2, name: "Sam", period: t+2...t+4},
      author_sam_v2: {b_id: 2, name: "Sam", period: t+4...t+6},
      author_sam_v3: {b_id: 2, name: "Sam", period: t+6...nil}
    },
    "Author" => {
      author_bob: {name: "Bob"},
      author_sam: {name: "Sam"}
    },
    "BookVersion" => {
      foo_v1: {b_id: 1, name: "Foo old", author_id: 1, period: t+2...t+4},
      foo_v2: {b_id: 1, name: "Foo new", author_id: 1, period: t+4...t+7},
      foo_v3: {b_id: 1, name: "Foo new", author_id: 2, period: t+7...nil}
    }
  }.each do |model, records|
    records.each do |method_name, attrs|
      let!(method_name) { model.constantize.create!(attrs) }
    end
  end

  describe "::existed_at" do
    it "scopes to records existing as of given time" do
      expect(AuthorVersion.existed_at(t+3))
        .to contain_exactly(author_bob_v2, author_sam_v1)
      expect(AuthorVersion.existed_at(t+5))
        .to contain_exactly(author_bob_v3, author_sam_v2)
      expect(AuthorVersion.existed_at(t+99))
        .to contain_exactly(author_bob_v3, author_sam_v3)
    end

    context "when column does not exist" do
      it "does not scope" do
        expect(Author.existed_at(t+3)).to eq(Author.all)
        expect(Author.existed_at(t+99)).to eq(Author.all)
      end
    end
  end

  describe "::extant" do
    it "scopes to existing records " do
      expect(AuthorVersion.extant)
        .to contain_exactly(author_bob_v3, author_sam_v3)
    end

    context "when column does not exist" do
      it "does not scope" do
        expect(Author.extant).to eq(Author.all)
      end
    end
  end

  describe "::as_of" do
    it "scopes by as-of and tags loaded records" do
      time = t+3
      relation = AuthorVersion.as_of(time)

      expect(relation).to contain_exactly(author_bob_v2, author_sam_v1)
      expect(relation).to all(have_attributes(period_as_of: time))
    end

    context "when column does not exist" do
      it "does not scope but still tags loaded records" do
        time = t+3
        relation = Author.as_of(time)

        expect(Author.as_of(time)).to eq(Author.all)
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
    def test_calling_associations_on_record(timeline)
      timeline.reject { _1.nil? }.each do |time, records|
        records.each do |record, expected|
          record = time ? record.as_of(time) : record

          expect(record).to have_attrs(expected.merge(period_as_of: time))
        end
      end
    end

    def test_eager_loading_associations(timeline)
      base_includes_test(timeline, :eager_load)
    end

    def test_preloading_associations(timeline)
      base_includes_test(timeline, :preload)
    end

    def base_includes_test(timeline, method)
      timeline.each do |time, records|
        rel = AuthorVersion.send(method, :books)
        rel = rel.as_of(time) if time

        authors = rel.to_a

        expect(authors)
          .to all(have_attrs(
            period_as_of: time,
            books: be_loaded
              .and(all(have_attrs(period_as_of: time)))
          ))

        expectations = records.map do |record, attrs|
          eq(record).and(have_attrs(attrs))
        end

        expect(authors).to contain_exactly(*expectations)
      end
    end

    before do
      AuthorVersion.class_eval do
        has_many :books,
          temporal_association_scope,
          primary_key: :b_id,
          foreign_key: :author_id,
          class_name: "BookVersion"
      end
    end

    it "applies temporal scopes to association" do
      timeline = {
        nil => {
          author_bob_v1 => {books: []},
          author_bob_v2 => {books: []},
          author_bob_v3 => {books: []},
          author_sam_v1 => {books: [foo_v3]},
          author_sam_v2 => {books: [foo_v3]},
          author_sam_v3 => {books: [foo_v3]}
        },
        t+1 => {
          author_bob_v1 => {books: []}
        },
        t+2 => {
          author_bob_v1 => {books: [foo_v1]},
          author_sam_v1 => {books: []}
        },
        t+3 => {
          author_bob_v2 => {books: [foo_v1]},
          author_sam_v1 => {books: []}
        },
        t+4 => {
          author_bob_v2 => {books: [foo_v2]},
          author_sam_v2 => {books: []}
        },
        t+5 => {
          author_bob_v3 => {books: [foo_v2]},
          author_sam_v2 => {books: []}
        },
        t+6 => {
          author_bob_v3 => {books: [foo_v2]},
          author_sam_v3 => {books: []}
        },
        t+7 => {
          author_bob_v3 => {books: []},
          author_sam_v3 => {books: [foo_v3]}
        }
      }

      test_calling_associations_on_record(timeline)
      test_eager_loading_associations(timeline)
      test_preloading_associations(timeline)
    end

    context "given a scope" do
      before do
        AuthorVersion.class_eval do
          has_many :books,
            temporal_association_scope { where(name: "Foo old") },
            primary_key: :b_id,
            foreign_key: :author_id,
            class_name: "BookVersion"
        end
      end

      it "merges temporal scopes with association's existing scope" do
        timeline = {
          nil => {
            author_bob_v1 => {books: []},
            author_bob_v2 => {books: []},
            author_bob_v3 => {books: []},
            author_sam_v1 => {books: []},
            author_sam_v2 => {books: []},
            author_sam_v3 => {books: []}
          },
          t+1 => {author_bob_v1 => {books: []}},
          t+2 => {
            author_bob_v1 => {books: [foo_v1]},
            author_sam_v1 => {books: []}
          },
          t+3 => {
            author_bob_v2 => {books: [foo_v1]},
            author_sam_v1 => {books: []}
          },
          t+4 => {author_bob_v2 => {books: []}, author_sam_v2 => {books: []}},
          t+5 => {author_bob_v3 => {books: []}, author_sam_v2 => {books: []}},
          t+6 => {author_bob_v3 => {books: []}, author_sam_v3 => {books: []}},
          t+7 => {author_bob_v3 => {books: []}, author_sam_v3 => {books: []}}
        }

        test_calling_associations_on_record(timeline)
        test_eager_loading_associations(timeline)
        test_preloading_associations(timeline)
      end
    end

    context "given an instance-dependent scope" do
      before do
        AuthorVersion.class_eval do
          has_many :books,
            temporal_association_scope { |owner|
              (owner.name == "Bob") ? where(name: "Foo new") : none
            },
            primary_key: :b_id,
            foreign_key: :author_id,
            class_name: "BookVersion"
        end
      end

      it "eager-loading raises an error" do
        expect { AuthorVersion.as_of(t+3).eager_load(:books).load }
          .to raise_error(ArgumentError, /is instance dependent/)
      end

      it "merges temporal scopes with association's existing scope" do
        timeline = {
          nil => {
            author_bob_v1 => {books: []},
            author_bob_v2 => {books: []},
            author_bob_v3 => {books: []},
            author_sam_v1 => {books: []},
            author_sam_v2 => {books: []},
            author_sam_v3 => {books: []}
          },
          t+1 => {
            author_bob_v1 => {books: []}
          },
          t+2 => {author_bob_v1 => {books: []}, author_sam_v1 => {books: []}},
          t+3 => {author_bob_v2 => {books: []}, author_sam_v1 => {books: []}},
          t+4 => {
            author_bob_v2 => {books: [foo_v2]},
            author_sam_v2 => {books: []}
          },
          t+5 => {
            author_bob_v3 => {books: [foo_v2]},
            author_sam_v2 => {books: []}
          },
          t+6 => {
            author_bob_v3 => {books: [foo_v2]},
            author_sam_v3 => {books: []}
          },
          t+7 => {author_bob_v3 => {books: []}, author_sam_v3 => {books: []}}
        }

        test_calling_associations_on_record(timeline)
        test_preloading_associations(timeline)
      end
    end
  end
end

# rubocop:enable Layout/SpaceAroundOperators
