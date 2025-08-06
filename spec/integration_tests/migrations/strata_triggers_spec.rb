require "spec_helper"

RSpec.describe "migrations for strata triggers" do
  around do |example|
    DatabaseCleaner.cleaning do
      example.run
    end
  end

  let(:connection) { ActiveRecord::Base.connection }

  describe "create_strata_triggers" do
    let(:migration) do
      Class.new(ActiveRecord::Migration[8.0]) do
        def change
          create_strata_triggers(:strata_books, :books, [:id, :title, :pages])
        end
      end.new
    end

    describe "up" do
      it "creates strata triggers" do
        migration.migrate(:up)

        expect(connection).to have_table(:books).with_trigger(:on_insert_strata_trigger)
        expect(connection).to have_table(:books).with_trigger(:on_update_strata_trigger)
        expect(connection).to have_table(:books).with_trigger(:on_delete_strata_trigger)
        expect(connection).to have_function(:strata_books_insert)
        expect(connection).to have_function(:strata_books_update)
        expect(connection).to have_function(:strata_books_delete)
      end
    end

    describe "down" do
      it "drops strata triggers" do
        migration.migrate(:up)
        migration.migrate(:down)

        expect(connection).not_to have_table(:books).with_trigger(:on_insert_strata_trigger)
        expect(connection).not_to have_table(:books).with_trigger(:on_update_strata_trigger)
        expect(connection).not_to have_table(:books).with_trigger(:on_delete_strata_trigger)
        expect(connection).not_to have_function(:strata_books_insert)
        expect(connection).not_to have_function(:strata_books_update)
        expect(connection).not_to have_function(:strata_books_delete)
      end
    end
  end

  # describe "drop_strata_triggers" do
  # end

  # describe "add_column_to_strata_triggers" do
  # end

  # describe "remove_column_from_strata_triggers" do
  # end
end
