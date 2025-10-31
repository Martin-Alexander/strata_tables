# rubocop:disable Layout/SpaceAroundOperators

require "spec_helper"

RSpec.describe "has many through" do
  before do
    model "Author" do
      has_many :books, primary_key: :b_id
      has_many :publishers, through: :books, primary_key: :b_id
      has_many :books, temporal_association_scope, primary_key: :b_id
      has_many :publishers, temporal_association_scope, through: :books, primary_key: :b_id
    end
    model "Book" do
      belongs_to :publisher, primary_key: :b_id
      belongs_to :publisher, temporal_association_scope, primary_key: :b_id
    end
    model "Publisher"
  end

  t = Time.parse("2000-01-01")

  context "when all tables have period columns" do
    before(:context) do
      table :authors do |t|
        t.tstzrange :period, null: false
      end
      table :publishers do |t|
        t.tstzrange :period, null: false
      end
      table :books do |t|
        t.references :author
        t.references :publisher
        t.tstzrange :period, null: false
      end
    end
    after(:context) { drop_all_tables }

    build_records do
      {
        "Author" => {
          author_v1: {b_id: 100, period: t+1...t+4},
          author_v2: {b_id: 100, period: t+4...nil}
        },
        "Book" => {
          book_1_v1: {b_id: 100, author_id: 100, publisher_id: 100, period: t+2...t+3},
          book_1_v2: {b_id: 100, author_id: 100, publisher_id: 101, period: t+3...nil},
          book_2_v1: {b_id: 101, author_id: 100, publisher_id: 101, period: t+4...nil}
        },
        "Publisher" => {
          publisher_1_v1: {b_id: 100, period: t+1...t+4},
          publisher_2_v1: {b_id: 101, period: t+3...t+5},
          publisher_2_v2: {b_id: 101, period: t+5...nil}

        }
      }
    end

    shared_context "non-distinct timeline" do
      let(:timeline) do
        {
          nil => [
            [author_v1, {publishers: [publisher_2_v2, publisher_2_v2]}],
            [author_v2, {publishers: [publisher_2_v2, publisher_2_v2]}]
          ],
          t+1 => [[author_v1, {publishers: []}]],
          t+2 => [[author_v1, {publishers: [publisher_1_v1]}]],
          t+3 => [[author_v1, {publishers: [publisher_2_v1]}]],
          t+4 => [[author_v2, {publishers: [publisher_2_v1, publisher_2_v1]}]],
          t+5 => [[author_v2, {publishers: [publisher_2_v2, publisher_2_v2]}]]
        }
      end
    end

    shared_context "distinct timeline" do
      let(:timeline) do
        {
          nil => [
            [author_v1, {publishers: [publisher_2_v2]}],
            [author_v2, {publishers: [publisher_2_v2]}]
          ],
          t+1 => [[author_v1, {publishers: []}]],
          t+2 => [[author_v1, {publishers: [publisher_1_v1]}]],
          t+3 => [[author_v1, {publishers: [publisher_2_v1]}]],
          t+4 => [[author_v2, {publishers: [publisher_2_v1]}]],
          t+5 => [[author_v2, {publishers: [publisher_2_v2]}]]
        }
      end
    end

    describe "#eager_load" do
      include_context "distinct timeline"

      test_eager_loading(n_steps: 6) { Author.eager_load(:publishers) }
    end

    describe "#preload" do
      include_context "non-distinct timeline"

      test_eager_loading(n_steps: 6) { Author.preload(:publishers) }
    end

    describe "association reader" do
      include_context "non-distinct timeline"

      test_association_reader(n_steps: 6)
    end
  end

  context "when through table has no period column" do
    before(:context) do
      table :authors do |t|
        t.tstzrange :period, null: false
      end
      table :publishers do |t|
        t.tstzrange :period, null: false
      end
      table :books do |t|
        t.references :author
        t.references :publisher
      end
    end
    after(:context) { drop_all_tables }

    build_records do
      {
        "Author" => {
          author_v1: {b_id: 100, period: t+1...nil}
        },
        "Book" => {
          book_1: {b_id: 100, author_id: 100, publisher_id: 100},
          book_2: {b_id: 101, author_id: 100, publisher_id: 101}
        },
        "Publisher" => {
          publisher_1_v1: {b_id: 100, period: t+1...t+4},
          publisher_2_v1: {b_id: 101, period: t+3...t+5},
          publisher_2_v2: {b_id: 101, period: t+5...nil}

        }
      }
    end

    let(:timeline) do
      {
        nil => [[author_v1, {publishers: [publisher_2_v2]}]],
        t+1 => [[author_v1, {publishers: [publisher_1_v1]}]],
        t+2 => [[author_v1, {publishers: [publisher_1_v1]}]],
        t+3 => [[author_v1, {publishers: [publisher_1_v1, publisher_2_v1]}]],
        t+4 => [[author_v1, {publishers: [publisher_2_v1]}]],
        t+5 => [[author_v1, {publishers: [publisher_2_v2]}]]
      }
    end

    describe "#eager_load" do
      test_eager_loading(n_steps: 6) { Author.eager_load(:publishers) }
    end

    describe "#preload" do
      test_eager_loading(n_steps: 6) { Author.preload(:publishers) }
    end

    describe "association reader" do
      test_association_reader(n_steps: 6)
    end
  end

  context "when target table has no period column" do
    before(:context) do
      table :authors do |t|
        t.tstzrange :period, null: false
      end
      table :publishers
      table :books do |t|
        t.references :author
        t.references :publisher
        t.tstzrange :period, null: false
      end
    end
    after(:context) { drop_all_tables }

    build_records do
      {
        "Author" => {
          author_v1: {b_id: 100, period: t+1...nil}
        },
        "Book" => {
          book_1_v1: {b_id: 100, author_id: 100, publisher_id: 100, period: t+2...t+3},
          book_1_v2: {b_id: 100, author_id: 100, publisher_id: 101, period: t+3...nil},
          book_2_v1: {b_id: 101, author_id: 100, publisher_id: 101, period: t+4...nil}
        },
        "Publisher" => {
          publisher_1: {b_id: 100},
          publisher_2: {b_id: 101}

        }
      }
    end

    shared_context "non-distinct timeline" do
      let(:timeline) do
        {
          nil => [[author_v1, {publishers: [publisher_2, publisher_2]}]],
          t+1 => [[author_v1, {publishers: []}]],
          t+2 => [[author_v1, {publishers: [publisher_1]}]],
          t+3 => [[author_v1, {publishers: [publisher_2]}]],
          t+4 => [[author_v1, {publishers: [publisher_2, publisher_2]}]],
          t+5 => [[author_v1, {publishers: [publisher_2, publisher_2]}]]
        }
      end
    end

    shared_context "distinct timeline" do
      let(:timeline) do
        {
          nil => [[author_v1, {publishers: [publisher_2]}]],
          t+1 => [[author_v1, {publishers: []}]],
          t+2 => [[author_v1, {publishers: [publisher_1]}]],
          t+3 => [[author_v1, {publishers: [publisher_2]}]],
          t+4 => [[author_v1, {publishers: [publisher_2]}]],
          t+5 => [[author_v1, {publishers: [publisher_2]}]]
        }
      end
    end

    describe "#eager_load" do
      include_context "distinct timeline"

      test_eager_loading(n_steps: 6) { Author.eager_load(:publishers) }
    end

    describe "#preload" do
      include_context "non-distinct timeline"

      test_eager_loading(n_steps: 6) { Author.preload(:publishers) }
    end

    describe "association reader" do
      include_context "non-distinct timeline"

      test_association_reader(n_steps: 6)
    end
  end

  context "when source table has no period column" do
    before(:context) do
      table :authors
      table :publishers do |t|
        t.tstzrange :period, null: false
      end
      table :books do |t|
        t.references :author
        t.references :publisher
        t.tstzrange :period, null: false
      end
    end
    after(:context) { drop_all_tables }

    build_records do
      {
        "Author" => {
          author_1: {b_id: 100}
        },
        "Book" => {
          book_1_v1: {b_id: 100, author_id: 100, publisher_id: 100, period: t+2...t+3},
          book_1_v2: {b_id: 100, author_id: 100, publisher_id: 101, period: t+3...nil},
          book_2_v1: {b_id: 101, author_id: 100, publisher_id: 101, period: t+4...nil}
        },
        "Publisher" => {
          publisher_1_v1: {b_id: 100, period: t+1...t+4},
          publisher_2_v1: {b_id: 101, period: t+3...t+5},
          publisher_2_v2: {b_id: 101, period: t+5...nil}

        }
      }
    end

    shared_context "non-distinct timeline" do
      let(:timeline) do
        {
          nil => [[author_1, {publishers: [publisher_2_v2, publisher_2_v2]}]],
          t+1 => [[author_1, {publishers: []}]],
          t+2 => [[author_1, {publishers: [publisher_1_v1]}]],
          t+3 => [[author_1, {publishers: [publisher_2_v1]}]],
          t+4 => [[author_1, {publishers: [publisher_2_v1, publisher_2_v1]}]],
          t+5 => [[author_1, {publishers: [publisher_2_v2, publisher_2_v2]}]]
        }
      end
    end

    shared_context "distinct timeline" do
      let(:timeline) do
        {
          nil => [[author_1, {publishers: [publisher_2_v2]}]],
          t+1 => [[author_1, {publishers: []}]],
          t+2 => [[author_1, {publishers: [publisher_1_v1]}]],
          t+3 => [[author_1, {publishers: [publisher_2_v1]}]],
          t+4 => [[author_1, {publishers: [publisher_2_v1]}]],
          t+5 => [[author_1, {publishers: [publisher_2_v2]}]]
        }
      end
    end

    describe "#eager_load" do
      include_context "distinct timeline"

      test_eager_loading(n_steps: 6) { Author.eager_load(:publishers) }
    end

    describe "#preload" do
      include_context "non-distinct timeline"

      test_eager_loading(n_steps: 6) { Author.preload(:publishers) }
    end

    describe "association reader" do
      include_context "non-distinct timeline"

      test_association_reader(n_steps: 6)
    end
  end
end

# rubocop:enable Layout/SpaceAroundOperators
