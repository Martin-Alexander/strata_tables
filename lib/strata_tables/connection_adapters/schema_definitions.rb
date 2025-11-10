module StrataTables
  module ConnectionAdapters
    class VersioningHookDefinition
      attr_accessor :source_table, :history_table, :columns

      def initialize(source_table, history_table, columns)
        @source_table = source_table
        @history_table = history_table
        @columns = columns
      end

      def insert_hook
        InsertHookDefinition.new(@source_table, @history_table, @columns)
      end

      def update_hook
        UpdateHookDefinition.new(@source_table, @history_table, @columns)
      end

      def delete_hook
        DeleteHookDefinition.new(@source_table, @history_table)
      end
    end

    InsertHookDefinition = Struct.new(:source_table, :history_table, :columns)

    UpdateHookDefinition = Struct.new(:source_table, :history_table, :columns)

    DeleteHookDefinition = Struct.new(:source_table, :history_table)
  end
end
