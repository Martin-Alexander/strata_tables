module StrataTables
  module ActiveRecord
    class StrataTriggerSetDefinition
      attr_reader :strata_table, :table, :column_names, :insert_trigger, :update_trigger, :delete_trigger

      def initialize(strata_table, table, column_names)
        @strata_table = strata_table
        @table = table
        @column_names = column_names

        @insert_trigger = StrataInsertTriggerDefinition.new(strata_table, table, column_names)
        @update_trigger = StrataUpdateTriggerDefinition.new(strata_table, table, column_names)
        @delete_trigger = StrataDeleteTriggerDefinition.new(strata_table, table)
      end

      def add_column(column_name)
        @column_names << column_name
      end

      def remove_column(column_name)
        @column_names.delete(column_name)
      end
    end

    StrataInsertTriggerDefinition = Struct.new(:strata_table, :table, :column_names)

    StrataUpdateTriggerDefinition = Struct.new(:strata_table, :table, :column_names)

    StrataDeleteTriggerDefinition = Struct.new(:strata_table, :table)
  end
end
