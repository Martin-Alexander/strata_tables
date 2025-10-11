module StrataTables
  module ConnectionAdapters
    module SchemaStatements
      def create_temporal_table(source_table, **options)
        except = options[:except]&.map(&:to_sym) || []

        source_columns = columns(source_table).reject do |column|
          except.include?(column.name.to_sym)
        end

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
