require "spec_helper"

RSpec.describe HistoryTables::ActiveRecord::SchemaCreation do
  around do |example|
    DatabaseCleaner.cleaning { example.run }
  end

  subject { described_class.new(connection) }

  let(:connection) { ActiveRecord::Base.connection }

  describe "#accept" do
    context "given HistoryInsertTriggerDefinition" do
      let(:object) do
        HistoryTables::ActiveRecord::HistoryInsertTriggerDefinition.new(
          :books,
          :history_books,
          [:id, :title, :pages, :published_at]
        )
      end

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

          COMMENT ON FUNCTION history_books_insert() IS '{"table":"books","history_table":"history_books","column_names":["id","title","pages","published_at"]}';

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
      let(:object) do
        HistoryTables::ActiveRecord::HistoryUpdateTriggerDefinition.new(
          :books,
          :history_books,
          [:id, :title, :pages, :published_at]
        )
      end

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

          COMMENT ON FUNCTION history_books_update() IS '{"table":"books","history_table":"history_books","column_names":["id","title","pages","published_at"]}';

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
      let(:object) do
        HistoryTables::ActiveRecord::HistoryDeleteTriggerDefinition.new(
          :books,
          :history_books
        )
      end

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

          COMMENT ON FUNCTION history_books_delete() IS '{"table":"books","history_table":"history_books"}';

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

    context "given DropHistoryTriggerDefinition" do
      let(:object) do
        HistoryTables::ActiveRecord::DropHistoryTriggerDefinition.new(:history_books_insert)
      end

      it "returns the correct SQL" do
        sql = subject.accept(object)

        expect(sql).to eq(<<~SQL.squish)
          DROP FUNCTION history_books_insert();
        SQL
      end

      context "with option :force" do
        let(:object) do
          HistoryTables::ActiveRecord::DropHistoryTriggerDefinition.new(:history_books_insert, force: true)
        end

        it "returns the correct SQL" do
          sql = subject.accept(object)

          expect(sql).to eq(<<~SQL.squish)
            DROP FUNCTION history_books_insert() CASCADE;
          SQL
        end
      end
    end
  end
end
