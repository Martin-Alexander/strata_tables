require "spec_helper"

RSpec.describe StrataTables::ConnectionAdapters::SchemaCreation do
  subject { described_class.new(connection) }

  let(:connection) { ActiveRecord::Base.connection }

  describe "#accept" do
    let(:insert_hook_definition) do
      StrataTables::ConnectionAdapters::InsertHookDefinition.new(
        :books,
        :books_history,
        [:id, :title, :pages, :published_at]
      )
    end

    let(:update_hook_definition) do
      StrataTables::ConnectionAdapters::UpdateHookDefinition.new(
        :books,
        :books_history,
        [:id, :title, :pages, :published_at]
      )
    end

    let(:delete_hook_definition) do
      StrataTables::ConnectionAdapters::DeleteHookDefinition.new(
        :books,
        :books_history
      )
    end

    context "given InsertHookDefinition" do
      let(:object) { insert_hook_definition }

      it "returns the correct SQL" do
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
    end

    context "given UpdateHookDefinition" do
      let(:object) { update_hook_definition }

      it "returns the correct SQL" do
        function_id = Digest::SHA256.hexdigest("books_update").first(10)
        expected_function_name = "sys_ver_func_" + function_id
        expected_function_comment = JSON.generate(
          verb: "update",
          source_table: "books",
          history_table: "books_history",
          columns: %w[id title pages published_at]
        )

        sql = subject.accept(object)

        expect(sql.squish).to eq(<<~SQL.squish)
          CREATE FUNCTION #{expected_function_name}() RETURNS trigger AS $$
            BEGIN
              IF OLD IS NOT DISTINCT FROM NEW THEN
                RETURN NULL;
              END IF;

              UPDATE "books_history"
              SET system_period = tstzrange(lower(system_period), NOW())
              WHERE id = OLD.id AND upper(system_period) = 'infinity' AND lower(system_period) < NOW();

              INSERT INTO "books_history" (id, title, pages, published_at, system_period)
              VALUES (NEW.id, NEW.title, NEW.pages, NEW.published_at, tstzrange(NOW(), 'infinity'))
              ON CONFLICT (id, system_period) DO UPDATE SET id = EXCLUDED.id, title = EXCLUDED.title, pages = EXCLUDED.pages, published_at = EXCLUDED.published_at;

              RETURN NULL;
            END;
          $$ LANGUAGE plpgsql;

          CREATE TRIGGER versioning_update_trigger AFTER UPDATE ON "books"
            FOR EACH ROW EXECUTE PROCEDURE #{expected_function_name}();

          COMMENT ON FUNCTION #{expected_function_name} IS '#{expected_function_comment}';
        SQL
      end
    end

    context "given DeleteHookDefinition" do
      let(:object) { delete_hook_definition }

      it "returns the correct SQL" do
        function_id = Digest::SHA256.hexdigest("books_delete").first(10)
        expected_function_name = "sys_ver_func_" + function_id
        expected_function_comment = JSON.generate(
          verb: "delete",
          source_table: "books",
          history_table: "books_history"
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
    end

    context "given VersioningHookDefinition" do
      let(:object) do
        StrataTables::ConnectionAdapters::VersioningHookDefinition.new(
          :books,
          :books_history,
          [:id, :title, :pages, :published_at]
        )
      end

      it "returns the correct SQL" do
        sql = subject.accept(object)

        expect(sql).to eq(
          [
            subject.accept(insert_hook_definition),
            subject.accept(update_hook_definition),
            subject.accept(delete_hook_definition)
          ].join(" ")
        )
      end
    end
  end
end
