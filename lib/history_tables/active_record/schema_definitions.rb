module HistoryTables
  module ActiveRecord
    class HistoryInsertTriggerDefinition
      attr_reader :table, :history_table, :column_names, :validity_column

      def initialize(table, history_table, column_names, validity_column = :validity)
        @table = table
        @history_table = history_table
        @column_names = column_names
        @validity_column = validity_column
      end
    end

    class HistoryUpdateTriggerDefinition
      attr_reader :table, :history_table, :column_names, :validity_column

      def initialize(table, history_table, column_names, validity_column = :validity)
        @table = table
        @history_table = history_table
        @column_names = column_names
        @validity_column = validity_column
      end
    end

    class HistoryDeleteTriggerDefinition
      attr_reader :table, :history_table, :validity_column

      def initialize(table, history_table, validity_column = :validity)
        @table = table
        @history_table = history_table
        @validity_column = validity_column
      end
    end

    class DropHistoryTriggerDefinition
      attr_reader :name, :force

      def initialize(name, force: false)
        @name = name
        @force = force
      end
    end
  end
end