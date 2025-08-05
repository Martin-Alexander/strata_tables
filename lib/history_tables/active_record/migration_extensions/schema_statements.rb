module HistoryTables
  module ActiveRecord
    module SchemaStatements
      def create_history_triggers(history_table, table, column_names)
        schema_creation = SchemaCreation.new(self)

        trigger_set = HistoryTriggerSetDefinition.new(history_table, table, column_names)

        execute schema_creation.accept(trigger_set)
      end

      def drop_history_triggers(history_table, table = nil, column_names = nil)
        execute "DROP FUNCTION #{history_table}_insert() CASCADE"
        execute "DROP FUNCTION #{history_table}_update() CASCADE"
        execute "DROP FUNCTION #{history_table}_delete() CASCADE"
      end

      def add_column_to_history_triggers(history_table, table, column_name)
        schema_creation = SchemaCreation.new(self)

        trigger_set = history_trigger_set(history_table, table)

        trigger_set.add_column(column_name)

        execute schema_creation.accept(trigger_set)
      end

      def remove_column_from_history_triggers(history_table, table, column_name)
        schema_creation = SchemaCreation.new(self)

        trigger_set = history_trigger_set(history_table, table)

        trigger_set.remove_column(column_name)

        execute schema_creation.accept(trigger_set)
      end

      # TODO: Error handling
      #
      def history_trigger_set(history_table, table)
        sql = <<~SQL.squish
          SELECT 
            (obj_description(p.oid)::json)->>'column_names' as column_names
          FROM pg_proc p 
          WHERE
            p.proname = '#{history_table}_insert'
        SQL

        results = execute(sql)

        return nil if results.count == 0

        column_names = JSON.parse(results[0]["column_names"]).map(&:to_sym) if results[0]["column_names"]

        HistoryTriggerSetDefinition.new(history_table, table, column_names)
      end
    end
  end
end
