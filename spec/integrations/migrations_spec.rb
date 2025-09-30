require "spec_helper"

RSpec.describe "migrations for temporal triggers" do
  migration_version = "#{ActiveRecord::VERSION::MAJOR}.#{ActiveRecord::VERSION::MINOR}"

  around do |example|
    og_verbose, ActiveRecord::Migration.verbose = ActiveRecord::Migration.verbose, false

    DatabaseCleaner.cleaning { example.run }

    ActiveRecord::Migration.verbose = og_verbose
  end

  before do
    conn.create_table(:books) do |t|
      t.string :title
    end
  end

  let(:migration) do
    migration_klass = Class.new(ActiveRecord::Migration[migration_version])

    migration_klass.define_method(:change, &migration_change)

    migration_klass.new
  end

  describe "create_temporal_table" do
    let(:migration_change) do
      -> { create_temporal_table(:books) }
    end

    describe "#up" do
      it "creates temporal table" do
        migration.migrate(:up)

        expect(conn).to have_table(:books_versions)

        expect(:books).to have_temporal_table
      end
    end

    describe "#down" do
      before { conn.create_temporal_table(:books) }

      it "drops temporal table" do
        migration.migrate(:down)

        expect(conn).not_to have_table(:books_versions)

        expect(conn)
          .to not_have_function(:strata_books_insert)
          .and not_have_function(:strata_books_update)
          .and not_have_function(:strata_books_delete)
      end
    end
  end

  describe "drop_temporal_table" do
    let(:migration_change) do
      -> { drop_temporal_table(:books) }
    end

    describe "#up" do
      before { conn.create_temporal_table(:books) }

      it "drops temporal table" do
        migration.migrate(:up)

        expect(conn).not_to have_table(:books_versions)
      end
    end

    describe "#down" do
      it "creates temporal table" do
        migration.migrate(:down)

        expect(conn).to have_table(:books_versions)

        expect(:books).to have_temporal_table
      end
    end
  end

  describe "add_temporal_column" do
    let(:migration_change) do
      -> { add_temporal_column(:books, :subtitle, :string) }
    end

    before do
      conn.create_temporal_table(:books)
      conn.add_column :books, :subtitle, :string
    end

    describe "#up" do
      it "adds temporal column" do
        migration.migrate(:up)

        expect(:books_versions).to have_column(:subtitle, :string)
      end
    end

    describe "#down" do
      before { conn.add_temporal_column(:books, :subtitle, :string) }

      it "removes temporal column" do
        migration.migrate(:down)

        expect(:books_versions).not_to have_column(:subtitle, :string)
      end
    end
  end

  describe "remove_temporal_column" do
    let(:migration_change) do
      -> { remove_temporal_column(:books, :title, :string) }
    end

    before { conn.create_temporal_table(:books) }

    describe "#up" do
      it "removes temporal column" do
        migration.migrate(:up)

        expect(:books_versions).not_to have_column(:title, :string)
      end
    end

    describe "#down" do
      before { conn.remove_temporal_column(:books, :title, :string) }

      it "adds temporal column" do
        migration.migrate(:down)

        expect(:books_versions).to have_column(:title, :string)
      end
    end
  end
end
