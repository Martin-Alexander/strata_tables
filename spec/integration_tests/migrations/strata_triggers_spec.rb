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
          create_strata_triggers(:books, strata_table: :strata_books, columns: [:id, :title, :pages])
        end
      end.new
    end

    describe "up" do
      it "creates strata triggers" do
        migration.migrate(:up)

        expect(connection).to have_table(:books).with_strata_triggers
        expect(connection).to have_function(:strata_books_insert)
        expect(connection).to have_function(:strata_books_update)
        expect(connection).to have_function(:strata_books_delete)
      end
    end

    describe "down" do
      it "drops strata triggers" do
        migration.migrate(:up)
        migration.migrate(:down)

        expect(connection).not_to have_table(:books).with_strata_triggers
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
