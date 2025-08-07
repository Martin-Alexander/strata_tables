require "spec_helper"

RSpec.describe "migrations for strata triggers" do
  conn = ActiveRecord::Base.connection

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
      Class.new(ActiveRecord::Migration[8.0]) do
        def change
          create_strata_table(:books)
        end
      end
    end

    describe "#up" do
      it "creates strata table" do
        migration.migrate(:up)

        expect(conn).to have_table(:books).with_strata_triggers
        expect(conn).to have_strata_functions(:strata_books)
      end
    end

    describe "#down" do
      before { conn.create_strata_table(:books) }

      it "drops strata table" do
        migration.migrate(:down)

        expect(conn).not_to have_table(:books).with_strata_triggers
        expect(conn).not_to have_strata_functions(:strata_books)
      end
    end
  end

  describe "drop_strata_table" do
    let(:migration_class) do
      Class.new(ActiveRecord::Migration[8.0]) do
        def change
          drop_strata_table(:books)
        end
      end
    end

    describe "#up" do
      before { conn.create_strata_table(:books) }

      it "drops strata table" do
        migration.migrate(:up)

        expect(conn).not_to have_table(:books).with_strata_triggers
        expect(conn).not_to have_strata_functions(:strata_books)
      end
    end

    describe "#down" do
      it "creates strata table" do
        migration.migrate(:down)

        expect(conn).to have_table(:books).with_strata_triggers
        expect(conn).to have_strata_functions(:strata_books)
      end
    end
  end

  describe "add_strata_column" do
    let(:migration_class) do
      Class.new(ActiveRecord::Migration[8.0]) do
        def change
          add_strata_column(:books, :author_id)
        end
      end
    end

    before do
      conn.create_strata_table(:books)
      conn.add_column :books, :author_id, :integer, null: false
    end

    describe "#up" do
      it "adds strata column" do
        migration.migrate(:up)

        expect(conn).to have_table(:strata_books).with_columns([
          [:hid, :integer],
          [:id, :integer],
          [:title, :string],
          [:pages, :integer],
          [:published_at, :date],
          [:validity, :tsrange],
          [:author_id, :integer]
        ])
      end
    end

    describe "#down" do
      before { conn.add_strata_column(:books, :author_id) }

      it "removes strata column" do
        migration.migrate(:down)

        expect(conn).to have_table(:strata_books).with_columns([
          [:hid, :integer],
          [:id, :integer],
          [:title, :string],
          [:pages, :integer],
          [:published_at, :date],
          [:validity, :tsrange]
        ])
      end
    end
  end

  describe "remove_strata_column" do
    let(:migration_class) do
      Class.new(ActiveRecord::Migration[8.0]) do
        def change
          remove_strata_column(:books, :title)
        end
      end
    end

    before { conn.create_strata_table(:books) }

    describe "#up" do
      it "removes strata column" do
        migration.migrate(:up)

        expect(conn).to have_table(:strata_books).with_columns([
          [:hid, :integer],
          [:id, :integer],
          [:pages, :integer],
          [:published_at, :date],
          [:validity, :tsrange]
        ])
      end
    end

    describe "#down" do
      before { conn.remove_strata_column(:books, :title) }

      it "adds strata column" do
        migration.migrate(:down)

        expect(conn).to have_table(:strata_books).with_columns([
          [:hid, :integer],
          [:id, :integer],
          [:title, :string],
          [:pages, :integer],
          [:published_at, :date],
          [:validity, :tsrange]
        ])
      end
    end
  end
end
