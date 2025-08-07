module StrataTables
  module ActiveRecord
    module SchemaStatements
      def create_strata_table(source_table)
        source_columns = columns(source_table)

        create_table :strata_books, primary_key: :hid do |t|
          source_columns.each do |column|
            t.send(column.type, column.name)
          end

          t.tsrange :validity, null: false
        end

        create_strata_triggers(source_table)
      end

      def drop_strata_table(source_table)
        drop_table :strata_books

        drop_strata_triggers(source_table)
      end

      def add_strata_column(source_table, column_name)
        source_columns = columns(source_table)

        new_column = source_columns.find { |c| c.name == column_name.to_s }

        add_column :strata_books, new_column.name, new_column.type

        drop_strata_triggers(source_table)
        create_strata_triggers(source_table)
      end

      def remove_strata_column(source_table, column_name)
        remove_column :strata_books, column_name

        drop_strata_triggers(source_table)
        create_strata_triggers(source_table)
      end

      def create_strata_triggers(source_table)
        schema_creation = SchemaCreation.new(self)

        strata_table = "strata_#{source_table}"
        column_names = columns(source_table).map(&:name)

        # raise ArgumentError, "Table '#{strata_table}' does not exist" unless table_exists?(strata_table)

        trigger_set = StrataTriggerSetDefinition.new(source_table, strata_table, column_names)

        execute schema_creation.accept(trigger_set)
      end

      def drop_strata_triggers(source_table)
        strata_table = "strata_#{source_table}"

        execute "DROP FUNCTION #{strata_table}_insert() CASCADE"
        execute "DROP FUNCTION #{strata_table}_update() CASCADE"
        execute "DROP FUNCTION #{strata_table}_delete() CASCADE"
      end
    end
  end
end
