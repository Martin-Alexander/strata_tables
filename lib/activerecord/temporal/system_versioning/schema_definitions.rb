module ActiveRecord::Temporal
  module SystemVersioning
    class VersioningHookDefinition
      attr_accessor :source_table, :history_table, :columns, :primary_key

      def initialize(
        source_table,
        history_table,
        columns:,
        primary_key:
      )
        @source_table = source_table
        @history_table = history_table
        @columns = columns
        @primary_key = primary_key
      end

      def insert_hook
        InsertHookDefinition.new(@source_table, @history_table, @columns)
      end

      def update_hook
        UpdateHookDefinition.new(@source_table, @history_table, @columns, @primary_key)
      end

      def delete_hook
        DeleteHookDefinition.new(@source_table, @history_table, @primary_key)
      end
    end

    InsertHookDefinition = Struct.new(:source_table, :history_table, :columns)

    UpdateHookDefinition = Struct.new(:source_table, :history_table, :columns, :primary_key)

    DeleteHookDefinition = Struct.new(:source_table, :history_table, :primary_key)
  end
end
