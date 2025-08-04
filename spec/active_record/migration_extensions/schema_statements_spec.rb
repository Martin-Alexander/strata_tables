require "spec_helper"

RSpec.describe HistoryTables::ActiveRecord::SchemaStatements do
  around do |example|
    DatabaseCleaner.cleaning { example.run }
  end

  let(:connection) { ActiveRecord::Base.connection }

  describe "#create_history_triggers" do
    context "when the history table exists" do
      before do
        connection.create_table :history_books, primary_key: :hid do |t|
          t.integer :id, null: false
          t.string :title
          t.integer :pages
          t.date :published_at
          t.tsrange :validity, null: false
          t.datetime :recorded_at, null: false
        end
      end

      it "creates an insert, update, and delete trigger" do
        connection.create_history_triggers(:books, :history_books, [:id, :title, :pages, :published_at])

        expect(connection).to have_function(:history_books_insert)
        expect(connection).to have_trigger(:books, :history_books_insert)
        expect(connection).to have_function(:history_books_update)
        expect(connection).to have_trigger(:books, :history_books_update)
        expect(connection).to have_function(:history_books_delete)
        expect(connection).to have_trigger(:books, :history_books_delete)
      end
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
  end
end
