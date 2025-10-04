module StrataTables
  module ConnectionAdapters
    module SchemaStatements
      def create_temporal_table(source_table)
        source_columns = columns(source_table)

        temporal_table = "#{source_table}_versions"

        create_table temporal_table, primary_key: :version_id do |t|
          source_columns.each do |column|
            t.send(
              column.type,
              column.name,
              comment: column.comment,
              collation: column.collation,
              default: column.default,
              limit: column.limit,
              null: column.null,
              precision: column.precision,
              scale: column.scale
            )
          end

          t.tstzrange :validity, null: false
        end

        create_temporal_triggers(source_table)
      end

      def drop_temporal_table(source_table)
        temporal_table = "#{source_table}_versions"

        drop_table temporal_table

        drop_temporal_triggers(source_table)
      end

      def add_temporal_column(source_table, column_name, type, **options)
        temporal_table = "#{source_table}_versions"

        add_column temporal_table, column_name, type, **options

        drop_temporal_triggers(source_table)
        create_temporal_triggers(source_table)
      end

      def remove_temporal_column(source_table, column_name, type = nil, **options)
        temporal_table = "#{source_table}_versions"

        remove_column temporal_table, column_name, type, **options

        drop_temporal_triggers(source_table)
        create_temporal_triggers(source_table)
      end

      def create_temporal_triggers(source_table)
        schema_creation = SchemaCreation.new(self)

        temporal_table = "#{source_table}_versions"
        column_names = columns(source_table).map(&:name)

        trigger_set = StrataTriggerSetDefinition.new(source_table, temporal_table, column_names)

        execute schema_creation.accept(trigger_set)
      end

      def drop_temporal_triggers(source_table)
        temporal_table = "#{source_table}_versions"

        execute "DROP FUNCTION #{temporal_table}_insert() CASCADE"
        execute "DROP FUNCTION #{temporal_table}_update() CASCADE"
        execute "DROP FUNCTION #{temporal_table}_delete() CASCADE"
      end
    end
  end
end
