require "spec_helper"

RSpec.describe HistoryTables::ActiveRecord::SchemaStatements do
  around do |example|
    DatabaseCleaner.cleaning { example.run }
  end

  let(:connection) { ActiveRecord::Base.connection }

  describe "#create_history_triggers" do
    it "creates an insert, update, and delete trigger" do
      connection.create_history_triggers(:books, :history_books, [:id, :title, :pages, :published_at])

      expect(connection).to have_function(:history_books_insert)
      expect(connection).to have_trigger(:books, :history_books_insert)
      expect(connection).to have_function(:history_books_update)
      expect(connection).to have_trigger(:books, :history_books_update)
      expect(connection).to have_function(:history_books_delete)
      expect(connection).to have_trigger(:books, :history_books_delete)
    end

    # context "when the history table does not exist" do
    # end

    # context "when the original table does not exist" do
    # end

    # context "when the history table is not actually a history table" do
    # end

    # context "when the history table and original table have different columns" do
    # end

    # context "when the original table already has a history trigger" do
    # end

    describe "inverse" do
      it "can be inverted by CommandRecorder" do
        recorder = ActiveRecord::Migration::CommandRecorder.new(connection)

        inverse = recorder.inverse_of(:create_history_triggers, [:books, :history_books, [:id, :title, :pages]])

        expect(inverse).to eq([:drop_history_triggers, [:history_books, :books, [:id, :title, :pages]]])
      end
    end
  end

  describe "#drop_history_triggers" do
    it "drops the insert, update, and delete triggers" do
      connection.create_history_triggers(:books, :history_books, [:id, :title, :pages, :published_at])

      connection.drop_history_triggers(:history_books)

      expect(connection).not_to have_function(:history_books_insert)
      expect(connection).not_to have_function(:history_books_update)
      expect(connection).not_to have_function(:history_books_delete)
    end

    describe "inverse" do
      it "can be inverted by CommandRecorder" do
        recorder = ActiveRecord::Migration::CommandRecorder.new(connection)

        inverse = recorder.inverse_of(:drop_history_triggers, [:history_books, :books, [:id, :title, :pages]])

        expect(inverse).to eq([:create_history_triggers, [:books, :history_books, [:id, :title, :pages]]])
      end
    end
  end
end
