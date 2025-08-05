module HistoryTables
  module ActiveRecord
    class SchemaCreation
      def initialize(conn)
        @conn = conn
      end

      def accept(o)
        m = "visit_#{o.class.name.split("::").last}"
        send m, o
      end

      delegate :quote_table_name, to: :@conn, private: true

      private

      def visit_HistoryInsertTriggerDefinition(o)
        fields = o.column_names.join(", ")
        values = o.column_names.map { |c| "NEW.#{c}" }.join(", ")
        comment = {
          table: o.table,
          history_table: o.history_table,
          column_names: o.column_names
        }.to_json

        <<-SQL.squish
          CREATE OR REPLACE FUNCTION #{o.history_table}_insert() RETURNS TRIGGER AS $$
            BEGIN
              INSERT INTO #{quote_table_name(o.history_table)} (#{fields}, #{o.validity_column})
              VALUES (#{values}, tsrange(timezone('UTC', now()), NULL));

              RETURN NULL;
            END;
          $$ LANGUAGE plpgsql;

          COMMENT ON FUNCTION #{o.history_table}_insert() IS '#{comment}';

          CREATE OR REPLACE TRIGGER history_insert AFTER INSERT ON #{quote_table_name(o.table)}
            FOR EACH ROW EXECUTE PROCEDURE #{o.history_table}_insert();
        SQL
      end

      def visit_HistoryUpdateTriggerDefinition(o)
        fields = o.column_names.join(", ")
        values = o.column_names.map { |c| "NEW.#{c}" }.join(", ")
        comment = {
          table: o.table,
          history_table: o.history_table,
          column_names: o.column_names
        }.to_json

        <<-SQL.squish
          CREATE OR REPLACE FUNCTION #{o.history_table}_update() RETURNS trigger AS $$
            BEGIN
              IF OLD IS NOT DISTINCT FROM NEW THEN
                RETURN NULL;
              END IF;

              UPDATE #{quote_table_name(o.history_table)}
              SET validity = tsrange(lower(validity), timezone('UTC', now()))
              WHERE
                id = OLD.id AND
                upper_inf(validity);

              INSERT INTO #{quote_table_name(o.history_table)} (#{fields}, #{o.validity_column})
              VALUES (#{values}, tsrange(timezone('UTC', now()), NULL));

              RETURN NULL;
            END;
          $$ LANGUAGE plpgsql;

          COMMENT ON FUNCTION #{o.history_table}_update() IS '#{comment}';

          CREATE OR REPLACE TRIGGER history_update AFTER UPDATE ON #{quote_table_name(o.table)}
            FOR EACH ROW EXECUTE PROCEDURE #{o.history_table}_update();
        SQL
      end

      def visit_HistoryDeleteTriggerDefinition(o)
        comment = {
          table: o.table,
          history_table: o.history_table
        }.to_json

        <<-SQL.squish
          CREATE OR REPLACE FUNCTION #{o.history_table}_delete() RETURNS TRIGGER AS $$
            BEGIN
              UPDATE #{quote_table_name(o.history_table)}
              SET validity = tsrange(lower(validity), timezone('UTC', now()))
              WHERE
                id = OLD.id AND
                upper_inf(validity);

              RETURN NULL;
            END;
          $$ LANGUAGE plpgsql;

          COMMENT ON FUNCTION #{o.history_table}_delete() IS '#{comment}';

          CREATE OR REPLACE TRIGGER history_delete AFTER DELETE ON #{quote_table_name(o.table)}
            FOR EACH ROW EXECUTE PROCEDURE #{o.history_table}_delete();
        SQL
      end
    end
  end
end
