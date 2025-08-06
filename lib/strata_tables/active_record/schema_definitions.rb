module StrataTables
  module ActiveRecord
    class StrataTriggerSetDefinition
      attr_reader :strata_table, :source_table, :columns, :insert_trigger, :update_trigger, :delete_trigger

      def initialize(strata_table, source_table, columns)
        @strata_table = strata_table
        @source_table = source_table
        @columns = columns

        @insert_trigger = InsertStrataTriggerDefinition.new(strata_table, source_table, columns)
        @update_trigger = UpdateStrataTriggerDefinition.new(strata_table, source_table, columns)
        @delete_trigger = DeleteStrataTriggerDefinition.new(strata_table, source_table)
      end

      def add_column(column)
        @columns << column
      end

      def remove_column(column)
        @columns.delete(column)
      end
    end

    InsertStrataTriggerDefinition = Struct.new(:strata_table, :source_table, :columns)

    UpdateStrataTriggerDefinition = Struct.new(:strata_table, :source_table, :columns)

    DeleteStrataTriggerDefinition = Struct.new(:strata_table, :source_table)
  end
end
