module HistoryTables
  module ActiveRecord
    module SchemaStatements
      def create_history_triggers(history_table, table, column_names)
        schema_creation = SchemaCreation.new(self)

        insert_trigger = HistoryInsertTriggerDefinition.new(table, history_table, column_names)
        execute schema_creation.accept(insert_trigger)

        update_trigger = HistoryUpdateTriggerDefinition.new(table, history_table, column_names)
        execute schema_creation.accept(update_trigger)

        delete_trigger = HistoryDeleteTriggerDefinition.new(table, history_table)
        execute schema_creation.accept(delete_trigger)
      end

      def drop_history_triggers(history_table, table = nil, column_names = nil)
        execute "DROP FUNCTION #{history_table}_insert() CASCADE"
        execute "DROP FUNCTION #{history_table}_update() CASCADE"
        execute "DROP FUNCTION #{history_table}_delete() CASCADE"
      end

      def add_column_to_history_triggers(history_table, table, column_name)
        schema_creation = SchemaCreation.new(self)

        history_triggers(history_table, table).each do |trigger|
          if trigger.respond_to?(:column_names)
            trigger.column_names << column_name
          end

          execute schema_creation.accept(trigger)
        end
      end

      def remove_column_from_history_triggers(history_table, table, column_name)
        schema_creation = SchemaCreation.new(self)

        history_triggers(history_table, table).each do |trigger|
          if trigger.respond_to?(:column_names)
            trigger.column_names.delete(column_name)
          end

          execute schema_creation.accept(trigger)
        end
      end

      def history_triggers(history_table, table)
        results = execute(<<~SQL)
          SELECT 
            CASE
              WHEN p.proname = '#{history_table}_insert' THEN 'insert'
              WHEN p.proname = '#{history_table}_update' THEN 'update'
              WHEN p.proname = '#{history_table}_delete' THEN 'delete'
            END as crud_action,
            (obj_description(p.oid)::json)->>'column_names' as column_names,
            (obj_description(p.oid)::json)->>'history_table' as history_table_name,
            (obj_description(p.oid)::json)->>'table' as table_name
          FROM pg_proc p 
          WHERE
            p.proname IN ('#{history_table}_insert', '#{history_table}_update', '#{history_table}_delete') AND
            (obj_description(p.oid)::json)->>'table' = '#{table}' AND
            (obj_description(p.oid)::json)->>'history_table' = '#{history_table}'
        SQL

        results.map do |result|
          column_names = JSON.parse(result["column_names"]).map(&:to_sym) if result["column_names"]
          table_name = result["table_name"]
          history_table_name = result["history_table_name"]

          case result["crud_action"]
          when "insert"
            HistoryInsertTriggerDefinition.new(table_name, history_table_name, column_names)
          when "update"
            HistoryUpdateTriggerDefinition.new(table_name, history_table_name, column_names)
          when "delete"
            HistoryDeleteTriggerDefinition.new(table_name, history_table_name)
          end
        end
      end
    end
  end
end
