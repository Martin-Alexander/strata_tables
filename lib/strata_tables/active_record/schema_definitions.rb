module StrataTables
  module ActiveRecord
    class StrataTriggerSetDefinition
      attr_reader :source_table, :strata_table, :column_names, :insert_trigger, :update_trigger, :delete_trigger

      def initialize(source_table, strata_table, column_names)
        @source_table = source_table
        @strata_table = strata_table
        @column_names = column_names

        @insert_trigger = InsertStrataTriggerDefinition.new(source_table, strata_table, column_names)
        @update_trigger = UpdateStrataTriggerDefinition.new(source_table, strata_table, column_names)
        @delete_trigger = DeleteStrataTriggerDefinition.new(source_table, strata_table)
      end

      def add_column(column)
        @column_names << column
      end

      def remove_column(column)
        @column_names.delete(column)
      end
    end

    InsertStrataTriggerDefinition = Struct.new(:source_table, :strata_table, :column_names)

    UpdateStrataTriggerDefinition = Struct.new(:source_table, :strata_table, :column_names)

    DeleteStrataTriggerDefinition = Struct.new(:source_table, :strata_table)
  end
end
