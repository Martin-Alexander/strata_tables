require "spec_helper"

RSpec.describe ConnectionAdapters::SchemaStatements do
  before do
    conn.create_table :authors do |t|
      t.string :first_name
      t.string :last_name
    end

    conn.create_table :authors_history, primary_key: [:id, :sys_period] do |t|
      t.bigint :id, null: false
      t.string :first_name
      t.string :last_name
      t.tstzrange :sys_period, null: false
    end
  end

  after do
    drop_all_tables
    drop_all_versioning_hooks
  end

  describe "#create_versioning_hook" do
    it "creates hook" do
      conn.create_versioning_hook(
        :authors,
        :authors_history,
        columns: [:first_name, :last_name]
      )

      function_names = spec_conn.plpgsql_functions.map(&:name)

      insert_id = Digest::SHA256.hexdigest("authors_insert").first(10)
      update_id = Digest::SHA256.hexdigest("authors_update").first(10)
      delete_id = Digest::SHA256.hexdigest("authors_delete").first(10)

      expect(function_names).to include(
        "sys_ver_func_#{insert_id}",
        "sys_ver_func_#{update_id}",
        "sys_ver_func_#{delete_id}"
      )

      expect(spec_conn.triggers(:authors)).to contain_exactly(
        "versioning_insert_trigger",
        "versioning_update_trigger",
        "versioning_delete_trigger"
      )
    end

    it "raises an error if columns don't match" do
      conn.create_table :books do |t|
        t.string :title
        t.bigint :author
      end

      conn.create_table :books_history, primary_key: [:id, :sys_period] do |t|
        t.bigint :id, null: false
        t.string :author
        t.string :publisher
        t.tstzrange :sys_period, null: false
      end

      expect do
        conn.create_versioning_hook(:books, :books_history, columns: [:title])
      end.to raise_error(ArgumentError, "table 'books_history' does not have column 'title'")

      expect do
        conn.create_versioning_hook(:books, :books_history, columns: [:publisher])
      end.to raise_error(ArgumentError, "table 'books' does not have column 'publisher'")

      expect do
        conn.create_versioning_hook(:books, :books_history, columns: [:author])
      end.to raise_error(ArgumentError, "table 'books_history' does not have column 'author' of type 'integer'")
    end

    it "raises an error if the hook already exists" do
      create_hook = -> do
        conn.create_versioning_hook(
          :authors,
          :authors_history,
          columns: [:first_name, :last_name]
        )
      end

      create_hook.call

      expect(&create_hook)
        .to raise_error(ActiveRecord::StatementInvalid, /PG::DuplicateFunction/)
    end
  end

  describe "#drop_versioning_hook" do
    before do
      conn.create_versioning_hook(
        :authors,
        :authors_history,
        columns: [:first_name, :last_name]
      )
    end

    it "drops the hook" do
      conn.drop_versioning_hook(
        :authors,
        :authors_history,
        columns: [:first_name, :last_name]
      )

      expect(spec_conn.plpgsql_functions.length).to eq(0)
      expect(spec_conn.triggers(:authors).length).to eq(0)
    end

    it "raises an error if the hook doesn't exist" do
      drop_hook = -> do
        conn.drop_versioning_hook(
          :authors,
          :authors_history,
          columns: [:first_name, :last_name]
        )
      end

      drop_hook.call

      expect(&drop_hook)
        .to raise_error(ActiveRecord::StatementInvalid, /PG::UndefinedFunction/)
    end
  end

  describe "#versioning_hook" do
    before do
      conn.create_versioning_hook(
        :authors,
        :authors_history,
        columns: [:first_name, :last_name]
      )
    end

    it "returns the hook" do
      expect(conn.versioning_hook(:authors)).to have_attributes(
        source_table: :authors,
        history_table: :authors_history,
        columns: contain_exactly(:first_name, :last_name)
      )
    end

    it "returns nil if the hook does not exist" do
      conn.create_table :books
      conn.create_table :books_history

      expect(conn.versioning_hook(:books)).to be_nil
      expect(conn.versioning_hook(:foo)).to be_nil
    end
  end

  describe "#change_versioning_hook" do
    before do
      conn.create_versioning_hook(
        :authors,
        :authors_history,
        columns: [:first_name, :last_name]
      )
    end

    describe "add_columns" do
      subject do
        conn.change_versioning_hook(
          :authors,
          :authors_history,
          add_columns: [:age]
        )
      end

      it "adds columns to hook" do
        conn.add_column(:authors, :age, :integer)
        conn.add_column(:authors_history, :age, :integer)

        subject

        versioning_hook = conn.versioning_hook(:authors)

        expect(versioning_hook.columns)
          .to contain_exactly(:first_name, :last_name, :age)
      end

      it "raises an error if source table does not have added column" do
        conn.add_column(:authors_history, :age, :integer)

        expect { subject }
          .to raise_error(ArgumentError, "table 'authors' does not have column 'age'")

        versioning_hook = conn.versioning_hook(:authors)

        expect(versioning_hook.columns).to contain_exactly(:first_name, :last_name)
      end

      it "raises an error if history table does not have added column" do
        conn.add_column(:authors, :age, :integer)

        expect { subject }
          .to raise_error(ArgumentError, "table 'authors_history' does not have column 'age'")

        versioning_hook = conn.versioning_hook(:authors)

        expect(versioning_hook.columns).to contain_exactly(:first_name, :last_name)
      end

      it "raises an error if column types do not match" do
        conn.add_column(:authors, :age, :string)
        conn.add_column(:authors_history, :age, :integer)

        expect { subject }
          .to raise_error(ArgumentError, "table 'authors_history' does not have column 'age' of type 'string'")

        versioning_hook = conn.versioning_hook(:authors)

        expect(versioning_hook.columns).to contain_exactly(:first_name, :last_name)
      end

      it "raises an error if either table does not exist" do
        expect do
          conn.change_versioning_hook(
            :foo,
            :authors_history,
            add_columns: [:age]
          )
        end.to raise_error(ActiveRecord::StatementInvalid, /PG::UndefinedTable/)

        expect do
          conn.change_versioning_hook(
            :authors,
            :foo,
            add_columns: [:age]
          )
        end.to raise_error(ActiveRecord::StatementInvalid, /PG::UndefinedTable/)

        versioning_hook = conn.versioning_hook(:authors)

        expect(versioning_hook.columns).to contain_exactly(:first_name, :last_name)
      end
    end

    describe "remove_columns" do
      it "removes columns from hook" do
        conn.change_versioning_hook(
          :authors,
          :authors_history,
          remove_columns: [:first_name]
        )

        versioning_hook = conn.versioning_hook(:authors)

        expect(versioning_hook.columns).to eq([:last_name])
      end

      it "raises an error if hook does not have those columns" do
        expect do
          conn.change_versioning_hook(
            :authors,
            :authors_history,
            remove_columns: [:middle_name]
          )
        end.to raise_error(ArgumentError, "versioning hook between 'authors' and 'authors_history' does not have column 'middle_name'")
      end

      it "raises an error if either table does not exist" do
        expect do
          conn.change_versioning_hook(
            :foo,
            :authors_history,
            remove_columns: [:first_name]
          )
        end.to raise_error(ActiveRecord::StatementInvalid, /PG::UndefinedTable/)

        expect do
          conn.change_versioning_hook(
            :authors,
            :foo,
            remove_columns: [:first_name]
          )
        end.to raise_error(ActiveRecord::StatementInvalid, /PG::UndefinedTable/)

        versioning_hook = conn.versioning_hook(:authors)

        expect(versioning_hook.columns).to contain_exactly(:first_name, :last_name)
      end
    end

    it "can add and remove columns at the same time" do
      conn.add_column(:authors, :age, :integer)
      conn.add_column(:authors_history, :age, :integer)

      conn.change_versioning_hook(
        :authors,
        :authors_history,
        add_columns: [:age],
        remove_columns: [:first_name]
      )

      versioning_hook = conn.versioning_hook(:authors)

      expect(versioning_hook.columns).to contain_exactly(:last_name, :age)
    end
  end
end
