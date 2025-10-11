module StrataTables
  module ConnectionAdapters
    module SchemaStatements
      def create_history_table(source_table, **options)
        except = options[:except]&.map(&:to_sym) || []

        source_columns = columns(source_table).reject do |column|
          except.include?(column.name.to_sym)
        end

        history_table = "#{source_table}_versions"

        create_table history_table, primary_key: :version_id do |t|
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

        create_history_triggers(source_table)
      end

      def drop_history_table(source_table)
        history_table = "#{source_table}_versions"

        drop_table history_table

        drop_history_triggers(source_table)
      end

      def create_history_triggers(source_table)
        schema_creation = SchemaCreation.new(self)

        history_table = "#{source_table}_versions"
        column_names = columns(source_table).map(&:name)

        trigger_set = StrataTriggerSetDefinition.new(source_table, history_table, column_names)

        execute schema_creation.accept(trigger_set)
      end

      def drop_history_triggers(source_table)
        history_table = "#{source_table}_versions"

        execute "DROP FUNCTION #{history_table}_insert() CASCADE"
        execute "DROP FUNCTION #{history_table}_update() CASCADE"
        execute "DROP FUNCTION #{history_table}_delete() CASCADE"
      end
    end
  end
end
