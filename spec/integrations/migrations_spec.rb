require "spec_helper"

RSpec.describe "migrations for strata triggers" do
  conn = ActiveRecord::Base.connection
  migration_version = "#{ActiveRecord::VERSION::MAJOR}.#{ActiveRecord::VERSION::MINOR}"

  around do |example|
    original_verbose = ActiveRecord::Migration.verbose
    ActiveRecord::Migration.verbose = false

    DatabaseCleaner.cleaning { example.run }

    ActiveRecord::Migration.verbose = original_verbose
  end

  let(:migration) do
    migration_class.new
  end

  describe "create_strata_table" do
    let(:migration_class) do
      Class.new(ActiveRecord::Migration[migration_version]) do
        def change
          create_strata_table(:books)
        end
      end
    end

    describe "#up" do
      it "creates strata table" do
        migration.migrate(:up)

        expect(conn).to have_table(:strata_books)

        expect(:books).to have_strata_table
      end
    end

    describe "#down" do
      before { conn.create_strata_table(:books) }

      it "drops strata table" do
        migration.migrate(:down)

        expect(conn).not_to have_table(:strata_books)

        expect(conn)
          .to not_have_function(:strata_books_insert)
          .and not_have_function(:strata_books_update)
          .and not_have_function(:strata_books_delete)
      end
    end
  end

  describe "drop_strata_table" do
    let(:migration_class) do
      Class.new(ActiveRecord::Migration[migration_version]) do
        def change
          drop_strata_table(:books)
        end
      end
    end

    describe "#up" do
      before { conn.create_strata_table(:books) }

      it "drops strata table" do
        migration.migrate(:up)

        expect(conn).not_to have_table(:strata_books)
      end
    end

    describe "#down" do
      it "creates strata table" do
        migration.migrate(:down)

        expect(conn).to have_table(:strata_books)

        expect(:books).to have_strata_table
      end
    end
  end

  describe "add_strata_column" do
    let(:migration_class) do
      Class.new(ActiveRecord::Migration[migration_version]) do
        def change
          add_strata_column(:books, :subtitle, :string)
        end
      end
    end

    before do
      conn.create_strata_table(:books)
      conn.add_column :books, :subtitle, :string
    end

    describe "#up" do
      it "adds strata column" do
        migration.migrate(:up)

        expect(:strata_books).to have_column(:subtitle, :string)
      end
    end

    describe "#down" do
      before { conn.add_strata_column(:books, :subtitle, :string) }

      it "removes strata column" do
        migration.migrate(:down)

        expect(:strata_books).not_to have_column(:subtitle, :string)
      end
    end
  end

  describe "remove_strata_column" do
    let(:migration_class) do
      Class.new(ActiveRecord::Migration[migration_version]) do
        def change
          remove_strata_column(:books, :title, :string)
        end
      end
    end

    before { conn.create_strata_table(:books) }

    describe "#up" do
      it "removes strata column" do
        migration.migrate(:up)

        expect(:strata_books).not_to have_column(:title, :string)
      end
    end

    describe "#down" do
      before { conn.remove_strata_column(:books, :title, :string) }

      it "adds strata column" do
        migration.migrate(:down)

        expect(:strata_books).to have_column(:title, :string)
      end
    end
  end
end
