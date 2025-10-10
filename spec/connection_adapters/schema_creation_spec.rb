require "spec_helper"

RSpec.describe StrataTables::ConnectionAdapters::SchemaCreation do
  subject { described_class.new(connection) }

  let(:connection) { ActiveRecord::Base.connection }

  describe "#accept" do
    let(:insert_trigger_definition) do
      StrataTables::ConnectionAdapters::InsertStrataTriggerDefinition.new(
        :books,
        :books_versions,
        [:id, :title, :pages, :published_at]
      )
    end

    let(:update_trigger_definition) do
      StrataTables::ConnectionAdapters::UpdateStrataTriggerDefinition.new(
        :books,
        :books_versions,
        [:id, :title, :pages, :published_at]
      )
    end

    let(:delete_trigger_definition) do
      StrataTables::ConnectionAdapters::DeleteStrataTriggerDefinition.new(
        :books,
        :books_versions
      )
    end

    context "given InsertStrataTriggerDefinition" do
      let(:object) { insert_trigger_definition }

      it "returns the correct SQL" do
        sql = subject.accept(object)

        expect(sql).to eq(<<~SQL.squish)
          CREATE OR REPLACE FUNCTION books_versions_insert() RETURNS TRIGGER AS $$
            BEGIN
              INSERT INTO "books_versions" (id, title, pages, published_at, validity)
              VALUES (NEW.id, NEW.title, NEW.pages, NEW.published_at, tstzrange(timezone('UTC', now()), NULL));

              RETURN NULL;
            END;
          $$ LANGUAGE plpgsql;

          CREATE OR REPLACE TRIGGER on_insert_strata_trigger AFTER INSERT ON "books"
            FOR EACH ROW EXECUTE PROCEDURE books_versions_insert();
        SQL
      end
    end

    context "given UpdateStrataTriggerDefinition" do
      let(:object) { update_trigger_definition }

      it "returns the correct SQL" do
        sql = subject.accept(object)

        expect(sql).to eq(<<~SQL.squish)
          CREATE OR REPLACE FUNCTION books_versions_update() RETURNS trigger AS $$
            BEGIN
              IF OLD IS NOT DISTINCT FROM NEW THEN
                RETURN NULL;
              END IF;

              UPDATE "books_versions"
              SET validity = tstzrange(lower(validity), timezone('UTC', now()))
              WHERE
                id = OLD.id AND
                upper_inf(validity);

              INSERT INTO "books_versions" (id, title, pages, published_at, validity)
              VALUES (NEW.id, NEW.title, NEW.pages, NEW.published_at, tstzrange(timezone('UTC', now()), NULL));

              RETURN NULL;
            END;
          $$ LANGUAGE plpgsql;

          CREATE OR REPLACE TRIGGER on_update_strata_trigger AFTER UPDATE ON "books"
            FOR EACH ROW EXECUTE PROCEDURE books_versions_update();
        SQL
      end
    end

    context "given DeleteStrataTriggerDefinition" do
      let(:object) { delete_trigger_definition }

      it "returns the correct SQL" do
        sql = subject.accept(object)

        expect(sql).to eq(<<~SQL.squish)
          CREATE OR REPLACE FUNCTION books_versions_delete() RETURNS TRIGGER AS $$
            BEGIN
              UPDATE "books_versions"
              SET validity = tstzrange(lower(validity), timezone('UTC', now()))
              WHERE
                id = OLD.id AND
                upper_inf(validity);

              RETURN NULL;
            END;
          $$ LANGUAGE plpgsql;

          CREATE OR REPLACE TRIGGER on_delete_strata_trigger AFTER DELETE ON "books"
            FOR EACH ROW EXECUTE PROCEDURE books_versions_delete();
        SQL
      end
    end

    context "given StrataTriggerSetDefinition" do
      let(:object) do
        StrataTables::ConnectionAdapters::StrataTriggerSetDefinition.new(
          :books,
          :books_versions,
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
