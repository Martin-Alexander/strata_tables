module StrataTables
  module ActiveRecord
    class StrataTriggerSetDefinition
      attr_reader :strata_table, :table, :column_names, :insert_trigger, :update_trigger, :delete_trigger

      def initialize(strata_table, table, column_names)
        @strata_table = strata_table
        @table = table
        @column_names = column_names

        @insert_trigger = InsertStrataTriggerDefinition.new(strata_table, table, column_names)
        @update_trigger = UpdateStrataTriggerDefinition.new(strata_table, table, column_names)
        @delete_trigger = DeleteStrataTriggerDefinition.new(strata_table, table)
      end

      def add_column(column_name)
        @column_names << column_name
      end

      def remove_column(column_name)
        @column_names.delete(column_name)
      end
    end

    InsertStrataTriggerDefinition = Struct.new(:strata_table, :table, :column_names)

    UpdateStrataTriggerDefinition = Struct.new(:strata_table, :table, :column_names)

    DeleteStrataTriggerDefinition = Struct.new(:strata_table, :table)
  end
end
