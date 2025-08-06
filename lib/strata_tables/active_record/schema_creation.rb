module StrataTables
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

      def visit_StrataTriggerSetDefinition(o)
        [o.insert_trigger, o.update_trigger, o.delete_trigger].map { |t| accept(t) }.join(" ")
      end

      def visit_InsertStrataTriggerDefinition(o)
        fields = o.columns.join(", ")
        values = o.columns.map { |c| "NEW.#{c}" }.join(", ")
        comment = {columns: o.columns}.to_json

        <<-SQL.squish
          CREATE OR REPLACE FUNCTION #{o.strata_table}_insert() RETURNS TRIGGER AS $$
            BEGIN
              INSERT INTO #{quote_table_name(o.strata_table)} (#{fields}, validity)
              VALUES (#{values}, tsrange(timezone('UTC', now()), NULL));

              RETURN NULL;
            END;
          $$ LANGUAGE plpgsql;

          COMMENT ON FUNCTION #{o.strata_table}_insert() IS '#{comment}';

          CREATE OR REPLACE TRIGGER on_insert_strata_trigger AFTER INSERT ON #{quote_table_name(o.source_table)}
            FOR EACH ROW EXECUTE PROCEDURE #{o.strata_table}_insert();
        SQL
      end

      def visit_UpdateStrataTriggerDefinition(o)
        fields = o.columns.join(", ")
        values = o.columns.map { |c| "NEW.#{c}" }.join(", ")
        comment = {columns: o.columns}.to_json

        <<-SQL.squish
          CREATE OR REPLACE FUNCTION #{o.strata_table}_update() RETURNS trigger AS $$
            BEGIN
              IF OLD IS NOT DISTINCT FROM NEW THEN
                RETURN NULL;
              END IF;

              UPDATE #{quote_table_name(o.strata_table)}
              SET validity = tsrange(lower(validity), timezone('UTC', now()))
              WHERE
                id = OLD.id AND
                upper_inf(validity);

              INSERT INTO #{quote_table_name(o.strata_table)} (#{fields}, validity)
              VALUES (#{values}, tsrange(timezone('UTC', now()), NULL));

              RETURN NULL;
            END;
          $$ LANGUAGE plpgsql;

          COMMENT ON FUNCTION #{o.strata_table}_update() IS '#{comment}';

          CREATE OR REPLACE TRIGGER on_update_strata_trigger AFTER UPDATE ON #{quote_table_name(o.source_table)}
            FOR EACH ROW EXECUTE PROCEDURE #{o.strata_table}_update();
        SQL
      end

      def visit_DeleteStrataTriggerDefinition(o)
        <<-SQL.squish
          CREATE OR REPLACE FUNCTION #{o.strata_table}_delete() RETURNS TRIGGER AS $$
            BEGIN
              UPDATE #{quote_table_name(o.strata_table)}
              SET validity = tsrange(lower(validity), timezone('UTC', now()))
              WHERE
                id = OLD.id AND
                upper_inf(validity);

              RETURN NULL;
            END;
          $$ LANGUAGE plpgsql;

          CREATE OR REPLACE TRIGGER on_delete_strata_trigger AFTER DELETE ON #{quote_table_name(o.source_table)}
            FOR EACH ROW EXECUTE PROCEDURE #{o.strata_table}_delete();
        SQL
      end
    end
  end
end
