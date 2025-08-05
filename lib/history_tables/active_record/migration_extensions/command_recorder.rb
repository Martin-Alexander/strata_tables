module HistoryTables
  module ActiveRecord
    module CommandRecorder
      def invert_create_history_triggers(args)
        history_table, table, column_names = args
        [:drop_history_triggers, [history_table, table, column_names]]
      end

      def invert_drop_history_triggers(args)
        history_table, table, column_names = args
        [:create_history_triggers, [history_table, table, column_names]]
      end

      def invert_add_column_to_history_triggers(args)
        history_table, table, column_name = args
        [:remove_column_from_history_triggers, [history_table, table, column_name]]
      end

      def invert_remove_column_from_history_triggers(args)
        history_table, table, column_name = args
        [:add_column_to_history_triggers, [history_table, table, column_name]]
      end

      def create_history_triggers(*args, &block)
        record(:create_history_triggers, args, &block)
      end

      def drop_history_triggers(*args, &block)
        record(:drop_history_triggers, args, &block)
      end

      def add_column_to_history_triggers(*args, &block)
        record(:add_column_to_history_triggers, args, &block)
      end

      def remove_column_from_history_triggers(*args, &block)
        record(:remove_column_from_history_triggers, args, &block)
      end
    end
  end
end
