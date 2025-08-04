module HistoryTables
  module ActiveRecord
    module SchemaStatements
      def create_history_triggers(table, history_table, column_names)
        schema_creation = SchemaCreation.new(self)

        insert_trigger = HistoryInsertTriggerDefinition.new(table, history_table, column_names)
        execute schema_creation.accept(insert_trigger)

        update_trigger = HistoryUpdateTriggerDefinition.new(table, history_table, column_names)
        execute schema_creation.accept(update_trigger)

        delete_trigger = HistoryDeleteTriggerDefinition.new(table, history_table)
        execute schema_creation.accept(delete_trigger)
      end

      def drop_history_triggers(history_table)
        schema_creation = SchemaCreation.new(self)

        execute schema_creation.accept(DropHistoryTriggerDefinition.new("#{history_table}_insert", force: true))
        execute schema_creation.accept(DropHistoryTriggerDefinition.new("#{history_table}_update", force: true))
        execute schema_creation.accept(DropHistoryTriggerDefinition.new("#{history_table}_delete", force: true))
      end
    end
  end
end
