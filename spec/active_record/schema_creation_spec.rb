require "spec_helper"

RSpec.describe HistoryTables::ActiveRecord::SchemaCreation do
  around do |example|
    DatabaseCleaner.cleaning { example.run }
  end

  subject { described_class.new(connection) }

  let(:connection) { ActiveRecord::Base.connection }

  describe "#accept" do
    let(:insert_trigger_definition) do
      HistoryTables::ActiveRecord::HistoryInsertTriggerDefinition.new(
        :history_books,
        :books,
        [:id, :title, :pages, :published_at]
      )
    end

    let(:update_trigger_definition) do
      HistoryTables::ActiveRecord::HistoryUpdateTriggerDefinition.new(
        :history_books,
        :books,
        [:id, :title, :pages, :published_at]
      )
    end

    let(:delete_trigger_definition) do
      HistoryTables::ActiveRecord::HistoryDeleteTriggerDefinition.new(
        :history_books,
        :books
      )
    end

    context "given HistoryInsertTriggerDefinition" do
      let(:object) { insert_trigger_definition }

      it "returns the correct SQL" do
        sql = subject.accept(object)

        expect(sql).to eq(<<~SQL.squish)
          CREATE OR REPLACE FUNCTION history_books_insert() RETURNS TRIGGER AS $$
            BEGIN
              INSERT INTO "history_books" (id, title, pages, published_at, validity)
              VALUES (NEW.id, NEW.title, NEW.pages, NEW.published_at, tsrange(timezone('UTC', now()), NULL));

              RETURN NULL;
            END;
          $$ LANGUAGE plpgsql;

          COMMENT ON FUNCTION history_books_insert() IS '{"column_names":["id","title","pages","published_at"]}';

          CREATE OR REPLACE TRIGGER history_insert AFTER INSERT ON "books"
            FOR EACH ROW EXECUTE PROCEDURE history_books_insert();
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

    context "given HistoryUpdateTriggerDefinition" do
      let(:object) { update_trigger_definition }

      it "returns the correct SQL" do
        sql = subject.accept(object)

        expect(sql).to eq(<<~SQL.squish)
          CREATE OR REPLACE FUNCTION history_books_update() RETURNS trigger AS $$
            BEGIN
              IF OLD IS NOT DISTINCT FROM NEW THEN
                RETURN NULL;
              END IF;

              UPDATE "history_books"
              SET validity = tsrange(lower(validity), timezone('UTC', now()))
              WHERE
                id = OLD.id AND
                upper_inf(validity);

              INSERT INTO "history_books" (id, title, pages, published_at, validity)
              VALUES (NEW.id, NEW.title, NEW.pages, NEW.published_at, tsrange(timezone('UTC', now()), NULL));

              RETURN NULL;
            END;
          $$ LANGUAGE plpgsql;

          COMMENT ON FUNCTION history_books_update() IS '{"column_names":["id","title","pages","published_at"]}';

          CREATE OR REPLACE TRIGGER history_update AFTER UPDATE ON "books"
            FOR EACH ROW EXECUTE PROCEDURE history_books_update();
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

    context "given HistoryDeleteTriggerDefinition" do
      let(:object) { delete_trigger_definition }

      it "returns the correct SQL" do
        sql = subject.accept(object)

        expect(sql).to eq(<<~SQL.squish)
          CREATE OR REPLACE FUNCTION history_books_delete() RETURNS TRIGGER AS $$
            BEGIN
              UPDATE "history_books"
              SET validity = tsrange(lower(validity), timezone('UTC', now()))
              WHERE
                id = OLD.id AND
                upper_inf(validity);

              RETURN NULL;
            END;
          $$ LANGUAGE plpgsql;

          CREATE OR REPLACE TRIGGER history_delete AFTER DELETE ON "books"
            FOR EACH ROW EXECUTE PROCEDURE history_books_delete();
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

    context "given HistoryTriggerSetDefinition" do
      let(:object) do
        HistoryTables::ActiveRecord::HistoryTriggerSetDefinition.new(
          :history_books,
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
