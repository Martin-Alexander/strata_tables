require "spec_helper"

RSpec.describe "migrations for history triggers" do
  around do |example|
    DatabaseCleaner.cleaning do
      example.run
    end
  end

  let(:connection) { ActiveRecord::Base.connection }

  let(:migration) do
    Class.new(ActiveRecord::Migration[8.0]) do
      def change
        create_history_triggers(:books, :history_books, [:id, :title, :pages])
      end
    end.new
  end

  describe "up" do
    it "creates history triggers" do
      migration.migrate(:up)

      expect(connection).to have_function(:history_books_insert)
      expect(connection).to have_function(:history_books_update)
      expect(connection).to have_function(:history_books_delete)
    end
  end

  describe "down" do
    it "drops history triggers" do
      migration.migrate(:up)
      migration.migrate(:down)

      expect(connection).not_to have_function(:history_books_insert)
      expect(connection).not_to have_function(:history_books_update)
      expect(connection).not_to have_function(:history_books_delete)
    end
  end
end
