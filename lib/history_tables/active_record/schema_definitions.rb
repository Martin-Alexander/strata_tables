module HistoryTables
  module ActiveRecord
    class HistoryTriggerSetDefinition
      attr_reader :history_table, :table, :column_names, :insert_trigger, :update_trigger, :delete_trigger

      def initialize(history_table, table, column_names)
        @history_table = history_table
        @table = table
        @column_names = column_names

        @insert_trigger = HistoryInsertTriggerDefinition.new(history_table, table, column_names)
        @update_trigger = HistoryUpdateTriggerDefinition.new(history_table, table, column_names)
        @delete_trigger = HistoryDeleteTriggerDefinition.new(history_table, table)
      end

      def add_column(column_name)
        @column_names << column_name
      end

      def remove_column(column_name)
        @column_names.delete(column_name)
      end
    end

    HistoryInsertTriggerDefinition = Struct.new(:history_table, :table, :column_names)

    HistoryUpdateTriggerDefinition = Struct.new(:history_table, :table, :column_names)

    HistoryDeleteTriggerDefinition = Struct.new(:history_table, :table)
  end
end
