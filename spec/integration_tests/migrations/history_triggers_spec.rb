require "spec_helper"

RSpec.describe "migrations for history triggers" do
  around do |example|
    DatabaseCleaner.cleaning do
      example.run
    end
  end

  let(:connection) { ActiveRecord::Base.connection }

  describe "create_history_triggers" do
    let(:migration) do
      Class.new(ActiveRecord::Migration[8.0]) do
        def change
          create_history_triggers(:history_books, :books, [:id, :title, :pages])
        end
      end.new
    end

    describe "up" do
      it "creates history triggers" do
        migration.migrate(:up)

        expect(connection).to have_table(:books).with_trigger(:history_insert)
        expect(connection).to have_table(:books).with_trigger(:history_update)
        expect(connection).to have_table(:books).with_trigger(:history_delete)
        expect(connection).to have_function(:history_books_insert)
        expect(connection).to have_function(:history_books_update)
        expect(connection).to have_function(:history_books_delete)
      end
    end

    describe "down" do
      it "drops history triggers" do
        migration.migrate(:up)
        migration.migrate(:down)

        expect(connection).not_to have_table(:books).with_trigger(:history_insert)
        expect(connection).not_to have_table(:books).with_trigger(:history_update)
        expect(connection).not_to have_table(:books).with_trigger(:history_delete)
        expect(connection).not_to have_function(:history_books_insert)
        expect(connection).not_to have_function(:history_books_update)
        expect(connection).not_to have_function(:history_books_delete)
      end
    end
  end

  # describe "drop_history_triggers" do
  # end

  # describe "add_column_to_history_triggers" do
  # end

  # describe "remove_column_from_history_triggers" do
  # end
end
