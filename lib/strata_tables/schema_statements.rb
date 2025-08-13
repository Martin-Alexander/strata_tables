module StrataTables
  module SchemaStatements
    def create_strata_table(source_table)
      source_columns = columns(source_table)

      strata_table = "strata_#{source_table}"

      create_table strata_table, primary_key: :hid do |t|
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

        t.tsrange :validity, null: false
      end

      create_strata_triggers(source_table)
    end

    def drop_strata_table(source_table)
      strata_table = "strata_#{source_table}"

      drop_table strata_table

      drop_strata_triggers(source_table)
    end

    def add_strata_column(source_table, column_name, type, **options)
      strata_table = "strata_#{source_table}"

      add_column strata_table, column_name, type, **options

      drop_strata_triggers(source_table)
      create_strata_triggers(source_table)
    end

    def remove_strata_column(source_table, column_name, type = nil, **options)
      strata_table = "strata_#{source_table}"

      remove_column strata_table, column_name, type, **options

      drop_strata_triggers(source_table)
      create_strata_triggers(source_table)
    end

    def create_strata_triggers(source_table)
      schema_creation = SchemaCreation.new(self)

      strata_table = "strata_#{source_table}"
      column_names = columns(source_table).map(&:name)

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
