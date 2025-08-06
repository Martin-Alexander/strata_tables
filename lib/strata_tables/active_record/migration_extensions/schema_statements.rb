module StrataTables
  module ActiveRecord
    module SchemaStatements
      def create_strata_triggers(strata_table, source_table, columns)
        schema_creation = SchemaCreation.new(self)

        trigger_set = StrataTriggerSetDefinition.new(strata_table, source_table, columns)

        execute schema_creation.accept(trigger_set)
      end

      def drop_strata_triggers(strata_table, source_table = nil, columns = nil)
        execute "DROP FUNCTION #{strata_table}_insert() CASCADE"
        execute "DROP FUNCTION #{strata_table}_update() CASCADE"
        execute "DROP FUNCTION #{strata_table}_delete() CASCADE"
      end

      def add_column_to_strata_triggers(strata_table, source_table, column)
        schema_creation = SchemaCreation.new(self)

        trigger_set = strata_trigger_set(strata_table, source_table)

        trigger_set.add_column(column)

        execute schema_creation.accept(trigger_set)
      end

      def remove_column_from_strata_triggers(strata_table, source_table, column)
        schema_creation = SchemaCreation.new(self)

        trigger_set = strata_trigger_set(strata_table, source_table)

        trigger_set.remove_column(column)

        execute schema_creation.accept(trigger_set)
      end

      # TODO: Error handling
      #
      def strata_trigger_set(strata_table, source_table)
        sql = <<~SQL.squish
          SELECT 
            (obj_description(p.oid)::json)->>'columns' as columns
          FROM pg_proc p 
          WHERE
            p.proname = '#{strata_table}_insert'
        SQL

        results = execute(sql)

        return nil if results.count == 0

        columns = JSON.parse(results[0]["columns"]).map(&:to_sym) if results[0]["columns"]

        StrataTriggerSetDefinition.new(strata_table, source_table, columns)
      end
    end
  end
end
