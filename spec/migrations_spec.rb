require "spec_helper"

RSpec.describe "migrations" do
  migration_version = "#{ActiveRecord::VERSION::MAJOR}.#{ActiveRecord::VERSION::MINOR}"

  around do |example|
    original, ActiveRecord::Migration.verbose = ActiveRecord::Migration.verbose, false

    example.run

    ActiveRecord::Migration.verbose = original
  end

  before do
    conn.create_table(:books) do |t|
      t.string :title
      t.string :author_name
    end
    conn.create_strata_metadata_table
  end

  after do
    conn.tables.each { |table| conn.drop_table(table, force: :cascade) }
  end

  let(:migration) do
    migration_klass = Class.new(ActiveRecord::Migration[migration_version])

    migration_klass.define_method(:change, &migration_change)

    migration_klass.new
  end

  describe "create_history_table_for :books" do
    let(:migration_change) do
      -> { create_history_table_for(:books) }
    end

    it "'up' creates history table" do
      migration.migrate(:up)

      books_history_table = conn.table(:books_history)

      expect(books_history_table).to be_present
      expect(books_history_table).to be_history_table_for(:books)
    end

    it "'down' drops history table" do
      migration.migrate(:up)
      migration.migrate(:down)

      books_table = conn.table(:books)
      books_history_table = conn.table(:books_history)

      expect(books_history_table).to be_nil
      expect(books_table)
        .to not_have_trigger(:on_insert_strata_trigger)
        .and not_have_trigger(:on_update_strata_trigger)
        .and not_have_trigger(:on_delete_strata_trigger)
      expect(conn)
        .to not_have_function(:books_history_insert)
        .and not_have_function(:books_history_update)
        .and not_have_function(:books_history_delete)
    end
  end

  describe "create_history_table_for :books, except: [:author_name]" do
    let(:migration_change) do
      -> { create_history_table_for(:books, except: [:author_name]) }
    end

    it "'up' creates history table" do
      migration.migrate(:up)

      books_history_table = conn.table(:books_history)

      expect(books_history_table).to be_present
      expect(books_history_table)
        .to be_history_table_for(:books)
        .and have_column(:title)
        .and not_have_column(:author_name)
    end

    it "'down' drops history table" do
      migration.migrate(:up)
      migration.migrate(:down)

      books_table = conn.table(:books)
      books_history_table = conn.table(:books_history)

      expect(books_history_table).to be_nil
      expect(books_table)
        .to not_have_trigger(:on_insert_strata_trigger)
        .and not_have_trigger(:on_update_strata_trigger)
        .and not_have_trigger(:on_delete_strata_trigger)
      expect(conn)
        .to not_have_function(:books_history_insert)
        .and not_have_function(:books_history_update)
        .and not_have_function(:books_history_delete)
    end
  end

  describe "drop_history_table" do
    before do
      conn.create_history_table_for(:books)
    end

    let(:migration_change) do
      -> { drop_history_table_for(:books) }
    end

    it "'up' drops history table" do
      migration.migrate(:up)

      books_table = conn.table(:books)
      books_history_table = conn.table(:books_history)

      expect(books_history_table).to be_nil
      expect(books_table)
        .to not_have_trigger(:on_insert_strata_trigger)
        .and not_have_trigger(:on_update_strata_trigger)
        .and not_have_trigger(:on_delete_strata_trigger)
      expect(conn)
        .to not_have_function(:books_history_insert)
        .and not_have_function(:books_history_update)
        .and not_have_function(:books_history_delete)
    end

    it "'down' creates history table" do
      migration.migrate(:up)
      migration.migrate(:down)

      books_history_table = conn.table(:books_history)

      expect(books_history_table).to be_present
      expect(books_history_table).to be_history_table_for(:books)
    end
  end

  describe "drop_history_table_for :books, except: [:author_name]" do
    before do
      conn.create_history_table_for(:books, except: [:author_name])
    end

    let(:migration_change) do
      -> { drop_history_table_for(:books, except: [:author_name]) }
    end

    it "'up' drops history table" do
      migration.migrate(:up)

      expect(conn.table(:books_history)).to be_nil
    end

    it "'down' creates history table" do
      migration.migrate(:up)
      migration.migrate(:down)

      books_history_table = conn.table(:books_history)

      expect(books_history_table).to be_present
      expect(books_history_table).to be_history_table_for(:books)
      expect(books_history_table)
        .to be_history_table_for(:books)
        .and have_column(:title)
        .and not_have_column(:author_name)
    end
  end

  describe "drop_history_table_for :books, :book_history" do
    before do
      conn.create_history_table_for(:books, :book_history)
    end

    let(:migration_change) do
      -> { drop_history_table_for(:books, :book_history) }
    end

    it "'up' drops history table" do
      migration.migrate(:up)

      expect(conn.table(:book_history)).to be_nil
    end

    it "'down' creates history table" do
      migration.migrate(:up)
      migration.migrate(:down)

      book_history_table = conn.table(:book_history)

      expect(book_history_table).to be_present
      expect(book_history_table).to be_history_table_for(:books)
    end
  end
end
