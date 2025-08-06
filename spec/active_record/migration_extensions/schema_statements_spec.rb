require "spec_helper"

RSpec.describe StrataTables::ActiveRecord::SchemaStatements do
  around do |example|
    DatabaseCleaner.cleaning { example.run }
  end

  let(:connection) { ActiveRecord::Base.connection }

  describe "#create_strata_triggers" do
    it "creates an insert, update, and delete trigger" do
      connection.create_strata_triggers(:strata_books, :books, [:id, :title, :pages, :published_at])

      expect(connection).to have_function(:strata_books_insert)
      expect(connection).to have_function(:strata_books_update)
      expect(connection).to have_function(:strata_books_delete)
      expect(connection).to have_table(:books).with_trigger(:strata_insert)
      expect(connection).to have_table(:books).with_trigger(:strata_update)
      expect(connection).to have_table(:books).with_trigger(:strata_delete)
    end

    # context "when the strata table does not exist" do
    # end

    # context "when the original table does not exist" do
    # end

    # context "when the strata table is not actually a strata table" do
    # end

    # context "when the strata table and original table have different columns" do
    # end

    # context "when the original table already has a strata trigger" do
    # end

    describe "inverse" do
      it "can be inverted by CommandRecorder" do
        recorder = ActiveRecord::Migration::CommandRecorder.new(connection)

        inverse = recorder.inverse_of(:create_strata_triggers, [:strata_books, :books, [:id, :title, :pages]])

        expect(inverse).to eq([:drop_strata_triggers, [:strata_books, :books, [:id, :title, :pages]]])
      end
    end
  end

  describe "#drop_strata_triggers" do
    it "drops the insert, update, and delete triggers" do
      connection.create_strata_triggers(:strata_books, :books, [:id, :title, :pages, :published_at])

      connection.drop_strata_triggers(:strata_books)

      expect(connection).not_to have_function(:strata_books_insert)
      expect(connection).not_to have_function(:strata_books_update)
      expect(connection).not_to have_function(:strata_books_delete)
      expect(connection).not_to have_table(:books).with_trigger(:strata_insert)
      expect(connection).not_to have_table(:books).with_trigger(:strata_update)
      expect(connection).not_to have_table(:books).with_trigger(:strata_delete)
    end

    describe "inverse" do
      it "can be inverted by CommandRecorder" do
        recorder = ActiveRecord::Migration::CommandRecorder.new(connection)

        inverse = recorder.inverse_of(:drop_strata_triggers, [:strata_books, :books, [:id, :title, :pages]])

        expect(inverse).to eq([:create_strata_triggers, [:strata_books, :books, [:id, :title, :pages]]])
      end
    end
  end

  describe "#add_column_to_strata_triggers" do
    it "adds a column to the strata table" do
      connection.create_strata_triggers(:strata_books, :books, [:id, :title, :pages, :published_at])

      connection.add_column_to_strata_triggers(:strata_books, :books, :author_id)

      trigger_set = connection.strata_trigger_set(:strata_books, :books)

      expect(trigger_set.column_names).to include(:author_id)
      expect(trigger_set.column_names).to include(:published_at)
    end

    # describe "inverse" do
    # end
  end

  describe "#remove_column_from_strata_triggers" do
    it "removes a column from the strata table" do
      connection.create_strata_triggers(:strata_books, :books, [:id, :title, :pages, :published_at])

      connection.remove_column_from_strata_triggers(:strata_books, :books, :author_id)

      trigger_set = connection.strata_trigger_set(:strata_books, :books)

      expect(trigger_set.column_names).not_to include(:author_id)
      expect(trigger_set.column_names).to include(:published_at)
    end

    # describe "inverse" do
    # end
  end

  # describe "#strata_triggers" do
  # end
end
