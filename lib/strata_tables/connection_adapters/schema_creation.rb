module StrataTables
  module ConnectionAdapters
    class SchemaCreation
      def initialize(conn)
        @conn = conn
      end

      def accept(o)
        m = "visit_#{o.class.name.split("::").last}"
        send m, o
      end

      delegate :quote_table_name, :history_callback_function_name, to: :@conn, private: true

      private

      def visit_StrataTriggerSetDefinition(o)
        [o.insert_trigger, o.update_trigger, o.delete_trigger].map { |t| accept(t) }.join(" ")
      end

      def visit_InsertStrataTriggerDefinition(o)
        fields = o.column_names.join(", ")
        values = o.column_names.map { |c| "NEW.#{c}" }.join(", ")
        function_name = history_callback_function_name(o.source_table, :insert)

        <<~SQL
          CREATE OR REPLACE FUNCTION #{function_name}() RETURNS TRIGGER AS $$
            BEGIN
              INSERT INTO #{quote_table_name(o.history_table)} (#{fields}, system_period)
              VALUES (#{values}, tstzrange(NOW(), 'infinity'));

              RETURN NULL;
            END;
          $$ LANGUAGE plpgsql;

          CREATE OR REPLACE TRIGGER on_insert_strata_trigger AFTER INSERT ON #{quote_table_name(o.source_table)}
            FOR EACH ROW EXECUTE PROCEDURE #{function_name}();
        SQL
      end

      def visit_UpdateStrataTriggerDefinition(o)
        fields = o.column_names.join(", ")
        values = o.column_names.map { |c| "NEW.#{c}" }.join(", ")
        on_conflict_sets = o.column_names.map { |c| "#{c} = EXCLUDED.#{c}" }.join(", ")
        function_name = history_callback_function_name(o.source_table, :update)

        <<~SQL
          CREATE OR REPLACE FUNCTION #{function_name}() RETURNS trigger AS $$
            BEGIN
              IF OLD IS NOT DISTINCT FROM NEW THEN
                RETURN NULL;
              END IF;

              UPDATE #{quote_table_name(o.history_table)}
              SET system_period = tstzrange(lower(system_period), NOW())
              WHERE id = OLD.id AND upper(system_period) = 'infinity' AND lower(system_period) < NOW();

              INSERT INTO #{quote_table_name(o.history_table)} (#{fields}, system_period)
              VALUES (#{values}, tstzrange(NOW(), 'infinity'))
              ON CONFLICT (id, system_start) DO UPDATE SET #{on_conflict_sets};

              RETURN NULL;
            END;
          $$ LANGUAGE plpgsql;

          CREATE OR REPLACE TRIGGER on_update_strata_trigger AFTER UPDATE ON #{quote_table_name(o.source_table)}
            FOR EACH ROW EXECUTE PROCEDURE #{function_name}();
        SQL
      end

      def visit_DeleteStrataTriggerDefinition(o)
        function_name = history_callback_function_name(o.source_table, :delete)

        <<~SQL
          CREATE OR REPLACE FUNCTION #{function_name}() RETURNS TRIGGER AS $$
            BEGIN
              DELETE FROM #{quote_table_name(o.history_table)}
              WHERE id = OLD.id AND system_period = tstzrange(NOW(), 'infinity');

              UPDATE #{quote_table_name(o.history_table)}
              SET system_period = tstzrange(lower(system_period), NOW())
              WHERE id = OLD.id AND upper(system_period) = 'infinity';

              RETURN NULL;
            END;
          $$ LANGUAGE plpgsql;

          CREATE OR REPLACE TRIGGER on_delete_strata_trigger AFTER DELETE ON #{quote_table_name(o.source_table)}
            FOR EACH ROW EXECUTE PROCEDURE #{function_name}();
        SQL
      end
    end
  end
end
