require "spec_helper"

RSpec.describe StrataTables::ActiveRecord::SchemaStatements do
  around do |example|
    DatabaseCleaner.cleaning { example.run }
  end

  subject { ActiveRecord::Base.connection }

  describe "#create_strata_table" do
    it "creates a strata table" do
      subject.create_strata_table(:books)

      is_expected.to have_table(:strata_books).with_columns([
        [:hid, :integer],
        [:id, :integer],
        [:title, :string],
        [:pages, :integer],
        [:published_at, :date],
        [:validity, :tsrange]
      ])
      is_expected.to have_strata_functions(:strata_books)
      is_expected.to have_table(:books).with_strata_triggers
    end
  end

  describe "#drop_strata_table" do
    before do
      subject.create_strata_table(:books)
    end

    it "drops a strata table" do
      subject.drop_strata_table(:books)

      is_expected.not_to have_table(:strata_books)
      is_expected.not_to have_strata_functions(:strata_books)
      is_expected.not_to have_table(:books).with_strata_triggers
    end
  end

  describe "#add_strata_column" do
    before do
      subject.create_strata_table(:books)
      subject.add_column :books, :author_id, :integer, null: false
    end

    it "adds a strata column" do
      subject.add_strata_column(:books, :author_id)

      is_expected.to have_table(:strata_books).with_columns([
        [:hid, :integer],
        [:id, :integer],
        [:title, :string],
        [:pages, :integer],
        [:published_at, :date],
        [:validity, :tsrange],
        [:author_id, :integer]
      ])
    end
  end

  describe "#remove_strata_column" do
    before do
      subject.create_strata_table(:books)
    end

    it "removes a strata column" do
      subject.remove_strata_column(:books, :title)

      is_expected.to have_table(:strata_books).with_columns([
        [:hid, :integer],
        [:id, :integer],
        [:pages, :integer],
        [:published_at, :date],
        [:validity, :tsrange]
      ])
    end
  end
end
