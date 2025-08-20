module StrataTables
  module ConnectionAdapters
    class StrataTriggerSetDefinition
      attr_reader :source_table, :temporal_table, :column_names, :insert_trigger, :update_trigger, :delete_trigger

      def initialize(source_table, temporal_table, column_names)
        @source_table = source_table
        @temporal_table = temporal_table
        @column_names = column_names

        @insert_trigger = InsertStrataTriggerDefinition.new(source_table, temporal_table, column_names)
        @update_trigger = UpdateStrataTriggerDefinition.new(source_table, temporal_table, column_names)
        @delete_trigger = DeleteStrataTriggerDefinition.new(source_table, temporal_table)
      end
    end

    InsertStrataTriggerDefinition = Struct.new(:source_table, :temporal_table, :column_names)

    UpdateStrataTriggerDefinition = Struct.new(:source_table, :temporal_table, :column_names)

    DeleteStrataTriggerDefinition = Struct.new(:source_table, :temporal_table)
  end
end
