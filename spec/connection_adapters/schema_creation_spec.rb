require "spec_helper"

RSpec.describe ConnectionAdapters::SchemaCreation do
  subject { described_class.new(ActiveRecord::Base.connection) }

  it "InsertHookDefinition returns the correct SQL" do
    object = ConnectionAdapters::InsertHookDefinition.new(
      :books,
      :books_history,
      [:id, :title, :pages, :published_at]
    )

    function_id = Digest::SHA256.hexdigest("books_insert").first(10)
    expected_function_name = "sys_ver_func_" + function_id
    expected_function_comment = JSON.generate(
      verb: "insert",
      source_table: "books",
      history_table: "books_history",
      columns: %w[id title pages published_at]
    )

    sql = subject.accept(object)

    expect(sql.squish).to eq(<<~SQL.squish)
      CREATE FUNCTION #{expected_function_name}() RETURNS TRIGGER AS $$
        BEGIN
          INSERT INTO "books_history" (id, title, pages, published_at, system_period)
          VALUES (NEW.id, NEW.title, NEW.pages, NEW.published_at, tstzrange(NOW(), 'infinity'));

          RETURN NULL;
        END;
      $$ LANGUAGE plpgsql;

      CREATE TRIGGER versioning_insert_trigger AFTER INSERT ON "books"
        FOR EACH ROW EXECUTE PROCEDURE #{expected_function_name}();

      COMMENT ON FUNCTION #{expected_function_name} IS '#{expected_function_comment}';
    SQL
  end

  it "UpdateHookDefinition returns the correct SQL" do
    object = ConnectionAdapters::UpdateHookDefinition.new(
      :books,
      :books_history,
      [:id, :title, :pages],
      [:id]
    )

    sql = subject.accept(object)

    function_id = Digest::SHA256.hexdigest("books_update").first(10)
    expected_function_name = "sys_ver_func_" + function_id
    expected_function_comment = JSON.generate(
      verb: :update,
      source_table: :books,
      history_table: :books_history,
      columns: [:id, :title, :pages],
      primary_key: [:id]
    )

    expect(sql.squish).to eq(<<~SQL.squish)
      CREATE FUNCTION #{expected_function_name}() RETURNS trigger AS $$
        BEGIN
          IF OLD IS NOT DISTINCT FROM NEW THEN
            RETURN NULL;
          END IF;

          UPDATE "books_history"
          SET system_period = tstzrange(lower(system_period), NOW())
          WHERE id = OLD.id AND upper(system_period) = 'infinity' AND lower(system_period) < NOW();

          INSERT INTO "books_history" (id, title, pages, system_period)
          VALUES (NEW.id, NEW.title, NEW.pages, tstzrange(NOW(), 'infinity'))
          ON CONFLICT (id, system_period) DO UPDATE SET id = EXCLUDED.id, title = EXCLUDED.title, pages = EXCLUDED.pages;

          RETURN NULL;
        END;
      $$ LANGUAGE plpgsql;

      CREATE TRIGGER versioning_update_trigger AFTER UPDATE ON "books"
        FOR EACH ROW EXECUTE PROCEDURE #{expected_function_name}();

      COMMENT ON FUNCTION #{expected_function_name} IS '#{expected_function_comment}';
    SQL
  end

  it "UpdateHookDefinition returns correct SQL given composite primary key" do
    object = ConnectionAdapters::UpdateHookDefinition.new(
      :books,
      :books_history,
      [:id, :title, :pages],
      [:id, :title]
    )

    sql = subject.accept(object)

    expect(sql).to include(<<~SQL)
      WHERE id = OLD.id AND title = OLD.title AND upper(system_period) = 'infinity' AND lower(system_period) < NOW();
    SQL

    expect(sql).to include(<<~SQL)
      ON CONFLICT (id, title, system_period) DO UPDATE SET id = EXCLUDED.id, title = EXCLUDED.title, pages = EXCLUDED.pages;
    SQL
  end

  it "DeleteHookDefinition returns the correct SQL" do
    object = ConnectionAdapters::DeleteHookDefinition.new(
      :books,
      :books_history,
      [:id]
    )

    function_id = Digest::SHA256.hexdigest("books_delete").first(10)
    expected_function_name = "sys_ver_func_" + function_id
    expected_function_comment = JSON.generate(
      verb: "delete",
      source_table: "books",
      history_table: "books_history",
      primary_key: [:id]
    )

    sql = subject.accept(object)

    expect(sql.squish).to eq(<<~SQL.squish)
      CREATE FUNCTION #{expected_function_name}() RETURNS TRIGGER AS $$
        BEGIN
          DELETE FROM "books_history"
          WHERE id = OLD.id AND system_period = tstzrange(NOW(), 'infinity');

          UPDATE "books_history"
          SET system_period = tstzrange(lower(system_period), NOW())
          WHERE id = OLD.id AND upper(system_period) = 'infinity';

          RETURN NULL;
        END;
      $$ LANGUAGE plpgsql;

      CREATE TRIGGER versioning_delete_trigger AFTER DELETE ON "books"
        FOR EACH ROW EXECUTE PROCEDURE #{expected_function_name}();

      COMMENT ON FUNCTION #{expected_function_name} IS '#{expected_function_comment}';
    SQL
  end

  it "DeleteHookDefinition returns the correct SQL given composite primary key" do
    object = ConnectionAdapters::DeleteHookDefinition.new(
      :books,
      :books_history,
      [:id, :title]
    )

    sql = subject.accept(object)

    expect(sql).to include(<<~SQL)
      WHERE id = OLD.id AND title = OLD.title AND system_period = tstzrange(NOW(), 'infinity');
    SQL

    expect(sql).to include(<<~SQL)
      WHERE id = OLD.id AND title = OLD.title AND upper(system_period) = 'infinity';
    SQL
  end

  it "VersioningHookDefinition returns the correct SQL" do
    columns = [:id, :title, :pages, :published_at]
    source_pk = [:id]

    object = ActiveRecord::Temporal::ConnectionAdapters::VersioningHookDefinition.new(
      :books,
      :books_history,
      columns: columns,
      primary_key: source_pk
    )

    sql = subject.accept(object)

    insert_hook_definition = ConnectionAdapters::InsertHookDefinition.new(
      :books,
      :books_history,
      columns
    )

    update_hook_definition = ConnectionAdapters::UpdateHookDefinition.new(
      :books,
      :books_history,
      columns,
      source_pk
    )

    delete_hook_definition = ConnectionAdapters::DeleteHookDefinition.new(
      :books,
      :books_history,
      source_pk
    )

    expect(sql).to eq(
      [
        subject.accept(insert_hook_definition),
        subject.accept(update_hook_definition),
        subject.accept(delete_hook_definition)
      ].join(" ")
    )
  end
end
