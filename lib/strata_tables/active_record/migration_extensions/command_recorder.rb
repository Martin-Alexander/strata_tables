module StrataTables
  module ActiveRecord
    module CommandRecorder
      def invert_create_strata_triggers(args)
        strata_table, source_table, columns = args
        [:drop_strata_triggers, [strata_table, source_table, columns]]
      end

      def invert_drop_strata_triggers(args)
        strata_table, source_table, columns = args
        [:create_strata_triggers, [strata_table, source_table, columns]]
      end

      def invert_add_column_to_strata_triggers(args)
        strata_table, source_table, column = args
        [:remove_column_from_strata_triggers, [strata_table, source_table, column]]
      end

      def invert_remove_column_from_strata_triggers(args)
        strata_table, source_table, column = args
        [:add_column_to_strata_triggers, [strata_table, source_table, column]]
      end

      def create_strata_triggers(*args, &block)
        record(:create_strata_triggers, args, &block)
      end

      def drop_strata_triggers(*args, &block)
        record(:drop_strata_triggers, args, &block)
      end

      def add_column_to_strata_triggers(*args, &block)
        record(:add_column_to_strata_triggers, args, &block)
      end

      def remove_column_from_strata_triggers(*args, &block)
        record(:remove_column_from_strata_triggers, args, &block)
      end
    end
  end
end
