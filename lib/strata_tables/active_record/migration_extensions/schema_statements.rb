module StrataTables
  module ActiveRecord
    module SchemaStatements
      def create_strata_triggers(source_table, **options)
        schema_creation = SchemaCreation.new(self)

        strata_table = options[:strata_table] || "strata_#{source_table}"
        column_names = options[:column_names] || columns(source_table).map(&:name)

        trigger_set = StrataTriggerSetDefinition.new(source_table, strata_table, column_names)

        execute schema_creation.accept(trigger_set)
      end

      def drop_strata_triggers(source_table, **options)
        strata_table = options[:strata_table] || "strata_#{source_table}"

        execute "DROP FUNCTION #{strata_table}_insert() CASCADE"
        execute "DROP FUNCTION #{strata_table}_update() CASCADE"
        execute "DROP FUNCTION #{strata_table}_delete() CASCADE"
      end

      def add_column_to_strata_triggers(source_table, column_name, **options)
        strata_table = options[:strata_table] || "strata_#{source_table}"

        schema_creation = SchemaCreation.new(self)

        trigger_set = strata_trigger_set(strata_table, source_table)

        trigger_set.add_column(column_name)

        execute schema_creation.accept(trigger_set)
      end

      def remove_column_from_strata_triggers(source_table, column_name, **options)
        strata_table = options[:strata_table] || "strata_#{source_table}"

        schema_creation = SchemaCreation.new(self)

        trigger_set = strata_trigger_set(strata_table, source_table)

        trigger_set.remove_column(column_name)

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

        column_names = JSON.parse(results[0]["columns"]).map(&:to_sym) if results[0]["columns"]

        StrataTriggerSetDefinition.new(source_table, strata_table, column_names)
      end
    end
  end
end
