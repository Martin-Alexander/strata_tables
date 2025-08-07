require "spec_helper"

RSpec.describe StrataTables::ActiveRecord::SchemaStatements do
  around do |example|
    DatabaseCleaner.cleaning { example.run }
  end

  subject { ActiveRecord::Base.connection }

  describe "#create_strata_triggers" do
    before { subject.create_strata_triggers(:books) }

    it { is_expected.to have_strata_functions(:strata_books).for_columns(%i[id title pages published_at]) }
    it { is_expected.to have_table(:books).with_strata_triggers }

    context "when strata_table is provided" do
      before { subject.create_strata_triggers(:books, strata_table: :history_books) }

      it { is_expected.to have_strata_functions(:history_books).for_columns(%i[id title pages published_at]) }
      it { is_expected.to have_table(:books).with_strata_triggers }
    end

    context "when column_names are provided" do
      before { subject.create_strata_triggers(:books, column_names: %i[id title]) }

      it { is_expected.to have_strata_functions(:strata_books).for_columns(%i[id title]) }
      it { is_expected.to have_table(:books).with_strata_triggers }
    end

    # context "when the strata table does not exist" do
    # end

    # context "when the source table does not exist" do
    # end

    # context "when the strata table is not actually a strata table" do
    # end

    # context "when the strata table and source table have different columns" do
    # end

    # context "when the source table already has a strata trigger" do
    # end
  end

  describe "#drop_strata_triggers" do
    before do
      subject.create_strata_triggers(:books)
      subject.drop_strata_triggers(:books)
    end

    it { is_expected.not_to have_strata_functions(:strata_books) }
    it { is_expected.not_to have_table(:books).with_strata_triggers }

    context "when strata_table is provided" do
      before do
        subject.create_strata_triggers(:books, strata_table: :history_books)
        subject.drop_strata_triggers(:books, strata_table: :history_books)
      end

      it { is_expected.not_to have_strata_functions(:history_books) }
      it { is_expected.not_to have_table(:books).with_strata_triggers }
    end
  end

  describe "#add_column_to_strata_triggers" do
    before do
      subject.create_strata_triggers(:books)
      subject.add_column_to_strata_triggers(:books, :author_id)
    end

    it { is_expected.to have_strata_functions(:strata_books).for_columns(%i[id title pages published_at author_id]) }

    context "when strata_table is provided" do
      before do
        subject.create_strata_triggers(:books, strata_table: :history_books)
        subject.add_column_to_strata_triggers(:books, :author_id, strata_table: :history_books)
      end

      it { is_expected.to have_strata_functions(:strata_books).for_columns(%i[id title pages published_at author_id]) }
    end
  end

  describe "#remove_column_from_strata_triggers" do
    before do
      subject.create_strata_triggers(:books)
      subject.remove_column_from_strata_triggers(:books, :published_at)
    end

    it { is_expected.to have_strata_functions(:strata_books).for_columns(%i[id title pages]) }

    context "when strata_table is provided" do
      before do
        subject.create_strata_triggers(:books, strata_table: :history_books)
        subject.remove_column_from_strata_triggers(:books, :published_at, strata_table: :history_books)
      end

      it { is_expected.to have_strata_functions(:strata_books).for_columns(%i[id title pages]) }
    end
  end

  # describe "#strata_triggers" do
  # end
end
