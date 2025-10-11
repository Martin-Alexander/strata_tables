require "spec_helper"

RSpec.describe "migrations for temporal triggers" do
  migration_version = "#{ActiveRecord::VERSION::MAJOR}.#{ActiveRecord::VERSION::MINOR}"

  around do |example|
    og_verbose, ActiveRecord::Migration.verbose = ActiveRecord::Migration.verbose, false

    example.run

    ActiveRecord::Migration.verbose = og_verbose
  end

  before do
    conn.create_table(:books) do |t|
      t.string :title
    end
  end

  after do
    conn.drop_table(:books) if conn.table_exists?(:books)
    conn.drop_table(:books_versions) if conn.table_exists?(:books_versions)
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
end
