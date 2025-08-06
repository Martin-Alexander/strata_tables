require "spec_helper"

RSpec.describe StrataTables::ActiveRecord::SchemaCreation do
  around do |example|
    DatabaseCleaner.cleaning { example.run }
  end

  subject { described_class.new(connection) }

  let(:connection) { ActiveRecord::Base.connection }

  describe "#accept" do
    let(:insert_trigger_definition) do
      StrataTables::ActiveRecord::InsertStrataTriggerDefinition.new(
        :strata_books,
        :books,
        [:id, :title, :pages, :published_at]
      )
    end

    let(:update_trigger_definition) do
      StrataTables::ActiveRecord::UpdateStrataTriggerDefinition.new(
        :strata_books,
        :books,
        [:id, :title, :pages, :published_at]
      )
    end

    let(:delete_trigger_definition) do
      StrataTables::ActiveRecord::DeleteStrataTriggerDefinition.new(
        :strata_books,
        :books
      )
    end

    context "given InsertStrataTriggerDefinition" do
      let(:object) { insert_trigger_definition }

      it "returns the correct SQL" do
        sql = subject.accept(object)

        expect(sql).to eq(<<~SQL.squish)
          CREATE OR REPLACE FUNCTION strata_books_insert() RETURNS TRIGGER AS $$
            BEGIN
              INSERT INTO "strata_books" (id, title, pages, published_at, validity)
              VALUES (NEW.id, NEW.title, NEW.pages, NEW.published_at, tsrange(timezone('UTC', now()), NULL));

              RETURN NULL;
            END;
          $$ LANGUAGE plpgsql;

          COMMENT ON FUNCTION strata_books_insert() IS '{"columns":["id","title","pages","published_at"]}';

          CREATE OR REPLACE TRIGGER on_insert_strata_trigger AFTER INSERT ON "books"
            FOR EACH ROW EXECUTE PROCEDURE strata_books_insert();
        SQL
      end

      # context "when column names are not specified" do
      # end

      # context "with option :if_not_exists" do
      # end

      # context "with option :force" do
      # end

      # context "with option :if_not_exists and :force" do
      # end
    end

    context "given UpdateStrataTriggerDefinition" do
      let(:object) { update_trigger_definition }

      it "returns the correct SQL" do
        sql = subject.accept(object)

        expect(sql).to eq(<<~SQL.squish)
          CREATE OR REPLACE FUNCTION strata_books_update() RETURNS trigger AS $$
            BEGIN
              IF OLD IS NOT DISTINCT FROM NEW THEN
                RETURN NULL;
              END IF;

              UPDATE "strata_books"
              SET validity = tsrange(lower(validity), timezone('UTC', now()))
              WHERE
                id = OLD.id AND
                upper_inf(validity);

              INSERT INTO "strata_books" (id, title, pages, published_at, validity)
              VALUES (NEW.id, NEW.title, NEW.pages, NEW.published_at, tsrange(timezone('UTC', now()), NULL));

              RETURN NULL;
            END;
          $$ LANGUAGE plpgsql;

          COMMENT ON FUNCTION strata_books_update() IS '{"columns":["id","title","pages","published_at"]}';

          CREATE OR REPLACE TRIGGER on_update_strata_trigger AFTER UPDATE ON "books"
            FOR EACH ROW EXECUTE PROCEDURE strata_books_update();
        SQL
      end

      # context "when column names are not specified" do
      # end

      # context "with option :if_not_exists" do
      # end

      # context "with option :force" do
      # end

      # context "with option :if_not_exists and :force" do
      # end
    end

    context "given DeleteStrataTriggerDefinition" do
      let(:object) { delete_trigger_definition }

      it "returns the correct SQL" do
        sql = subject.accept(object)

        expect(sql).to eq(<<~SQL.squish)
          CREATE OR REPLACE FUNCTION strata_books_delete() RETURNS TRIGGER AS $$
            BEGIN
              UPDATE "strata_books"
              SET validity = tsrange(lower(validity), timezone('UTC', now()))
              WHERE
                id = OLD.id AND
                upper_inf(validity);

              RETURN NULL;
            END;
          $$ LANGUAGE plpgsql;

          CREATE OR REPLACE TRIGGER on_delete_strata_trigger AFTER DELETE ON "books"
            FOR EACH ROW EXECUTE PROCEDURE strata_books_delete();
        SQL
      end

      # context "when column names are not specified" do
      # end

      # context "with option :if_not_exists" do
      # end

      # context "with option :force" do
      # end

      # context "with option :if_not_exists and :force" do
      # end
    end

    context "given StrataTriggerSetDefinition" do
      let(:object) do
        StrataTables::ActiveRecord::StrataTriggerSetDefinition.new(
          :strata_books,
          :books,
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
