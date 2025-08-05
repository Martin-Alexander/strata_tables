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

      def create_history_triggers(*args, &block)
        record(:create_history_triggers, args, &block)
      end

      def drop_history_triggers(*args, &block)
        record(:drop_history_triggers, args, &block)
      end
    end
  end
end
