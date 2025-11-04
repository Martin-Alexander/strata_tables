require "spec_helper"

RSpec.describe StrataTables::ConnectionAdapters::SchemaCreation do
  subject { described_class.new(connection) }

  let(:connection) { ActiveRecord::Base.connection }

  describe "#accept" do
    let(:insert_trigger_definition) do
      StrataTables::ConnectionAdapters::InsertStrataTriggerDefinition.new(
        :books,
        :books_history,
        [:id, :title, :pages, :published_at]
      )
    end

    let(:update_trigger_definition) do
      StrataTables::ConnectionAdapters::UpdateStrataTriggerDefinition.new(
        :books,
        :books_history,
        [:id, :title, :pages, :published_at]
      )
    end

    let(:delete_trigger_definition) do
      StrataTables::ConnectionAdapters::DeleteStrataTriggerDefinition.new(
        :books,
        :books_history
      )
    end

    context "given InsertStrataTriggerDefinition" do
      let(:object) { insert_trigger_definition }

      it "returns the correct SQL" do
        sql = subject.accept(object)

        expect(sql.squish).to eq(<<~SQL.squish)
          CREATE OR REPLACE FUNCTION strata_cb_3c9e7bcd97() RETURNS TRIGGER AS $$
            BEGIN
              INSERT INTO "books_history" (id, title, pages, published_at, system_period)
              VALUES (NEW.id, NEW.title, NEW.pages, NEW.published_at, tstzrange(NOW(), 'infinity'));

              RETURN NULL;
            END;
          $$ LANGUAGE plpgsql;

          CREATE OR REPLACE TRIGGER on_insert_strata_trigger AFTER INSERT ON "books"
            FOR EACH ROW EXECUTE PROCEDURE strata_cb_3c9e7bcd97();
        SQL
      end
    end

    context "given UpdateStrataTriggerDefinition" do
      let(:object) { update_trigger_definition }

      it "returns the correct SQL" do
        sql = subject.accept(object)

        expect(sql.squish).to eq(<<~SQL.squish)
          CREATE OR REPLACE FUNCTION strata_cb_a0409343fa() RETURNS trigger AS $$
            BEGIN
              IF OLD IS NOT DISTINCT FROM NEW THEN
                RETURN NULL;
              END IF;

              UPDATE "books_history"
              SET system_period = tstzrange(lower(system_period), NOW())
              WHERE id = OLD.id AND upper(system_period) = 'infinity' AND lower(system_period) < NOW();

              INSERT INTO "books_history" (id, title, pages, published_at, system_period)
              VALUES (NEW.id, NEW.title, NEW.pages, NEW.published_at, tstzrange(NOW(), 'infinity'))
              ON CONFLICT (id, system_start) DO UPDATE SET id = EXCLUDED.id, title = EXCLUDED.title, pages = EXCLUDED.pages, published_at = EXCLUDED.published_at;

              RETURN NULL;
            END;
          $$ LANGUAGE plpgsql;

          CREATE OR REPLACE TRIGGER on_update_strata_trigger AFTER UPDATE ON "books"
            FOR EACH ROW EXECUTE PROCEDURE strata_cb_a0409343fa();
        SQL
      end
    end

    context "given DeleteStrataTriggerDefinition" do
      let(:object) { delete_trigger_definition }

      it "returns the correct SQL" do
        sql = subject.accept(object)

        expect(sql.squish).to eq(<<~SQL.squish)
          CREATE OR REPLACE FUNCTION strata_cb_1bf6acb0c3() RETURNS TRIGGER AS $$
            BEGIN
              DELETE FROM "books_history"
              WHERE id = OLD.id AND system_period = tstzrange(NOW(), 'infinity');

              UPDATE "books_history"
              SET system_period = tstzrange(lower(system_period), NOW())
              WHERE id = OLD.id AND upper(system_period) = 'infinity';

              RETURN NULL;
            END;
          $$ LANGUAGE plpgsql;

          CREATE OR REPLACE TRIGGER on_delete_strata_trigger AFTER DELETE ON "books"
            FOR EACH ROW EXECUTE PROCEDURE strata_cb_1bf6acb0c3();
        SQL
      end
    end

    context "given StrataTriggerSetDefinition" do
      let(:object) do
        StrataTables::ConnectionAdapters::StrataTriggerSetDefinition.new(
          :books,
          :books_history,
          [:id, :title, :pages, :published_at]
        )
      end

      it "returns the correct SQL" do
        sql = subject.accept(object)

        expect(sql).to eq(
          [
            subject.accept(insert_trigger_definition),
            subject.accept(update_trigger_definition),
            subject.accept(delete_trigger_definition)
          ].join(" ")
        )
      end
    end
  end
end
