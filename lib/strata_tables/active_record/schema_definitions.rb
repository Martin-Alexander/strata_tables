module StrataTables
  module ActiveRecord
    class StrataTriggerSetDefinition
      attr_reader :source_table, :strata_table, :columns, :insert_trigger, :update_trigger, :delete_trigger

      def initialize(source_table, strata_table, columns)
        @source_table = source_table
        @strata_table = strata_table
        @columns = columns

        @insert_trigger = InsertStrataTriggerDefinition.new(source_table, strata_table, columns)
        @update_trigger = UpdateStrataTriggerDefinition.new(source_table, strata_table, columns)
        @delete_trigger = DeleteStrataTriggerDefinition.new(source_table, strata_table)
      end

      def add_column(column)
        @columns << column
      end

      def remove_column(column)
        @columns.delete(column)
      end
    end

    InsertStrataTriggerDefinition = Struct.new(:source_table, :strata_table, :columns)

    UpdateStrataTriggerDefinition = Struct.new(:source_table, :strata_table, :columns)

    DeleteStrataTriggerDefinition = Struct.new(:source_table, :strata_table)
  end
end
