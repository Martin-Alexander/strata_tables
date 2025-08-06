module StrataTables
  module ActiveRecord
    module SchemaStatements
      def create_strata_triggers(strata_table, table, column_names)
        schema_creation = SchemaCreation.new(self)

        trigger_set = StrataTriggerSetDefinition.new(strata_table, table, column_names)

        execute schema_creation.accept(trigger_set)
      end

      def drop_strata_triggers(strata_table, table = nil, column_names = nil)
        execute "DROP FUNCTION #{strata_table}_insert() CASCADE"
        execute "DROP FUNCTION #{strata_table}_update() CASCADE"
        execute "DROP FUNCTION #{strata_table}_delete() CASCADE"
      end

      def add_column_to_strata_triggers(strata_table, table, column_name)
        schema_creation = SchemaCreation.new(self)

        trigger_set = strata_trigger_set(strata_table, table)

        trigger_set.add_column(column_name)

        execute schema_creation.accept(trigger_set)
      end

      def remove_column_from_strata_triggers(strata_table, table, column_name)
        schema_creation = SchemaCreation.new(self)

        trigger_set = strata_trigger_set(strata_table, table)

        trigger_set.remove_column(column_name)

        execute schema_creation.accept(trigger_set)
      end

      # TODO: Error handling
      #
      def strata_trigger_set(strata_table, table)
        sql = <<~SQL.squish
          SELECT 
            (obj_description(p.oid)::json)->>'column_names' as column_names
          FROM pg_proc p 
          WHERE
            p.proname = '#{strata_table}_insert'
        SQL

        results = execute(sql)

        return nil if results.count == 0

        column_names = JSON.parse(results[0]["column_names"]).map(&:to_sym) if results[0]["column_names"]

        StrataTriggerSetDefinition.new(strata_table, table, column_names)
      end
    end
  end
end
