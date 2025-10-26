module StrataTables
  module ConnectionAdapters
    module SchemaStatements
      def create_strata_metadata_table
        create_table :strata_metadata, id: false do |t|
          t.primary_keys [:history_table]
          t.string :history_table
          t.string :temporal_table
        end
      end

      def create_history_table_for(source_table, history_table = nil, **options)
        except = options[:except]&.map(&:to_sym) || []

        source_columns = columns(source_table).reject do |column|
          except.include?(column.name.to_sym)
        end

        history_table ||= "#{source_table}_history"

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

          t.tstzrange :sys_period, null: false

          if extension_enabled?(:btree_gist)
            t.exclusion_constraint("id WITH =, sys_period WITH &&", using: :gist)
          end
        end

        recreate_history_triggers(source_table)
        register_history_table(history_table, source_table)

        if options[:copy_data]
          copy_data(
            source_table,
            history_table,
            source_columns,
            options[:copy_data]
          )
        end
      end

      def drop_history_table_for(source_table, history_table = nil, **options)
        history_table ||= history_table_for(source_table)

        drop_table(history_table)
        drop_history_triggers(source_table)
        unregister_history_table(history_table, source_table)
      end

      def recreate_history_triggers(source_table)
        schema_creation = SchemaCreation.new(self)

        history_table = "#{source_table}_history"
        column_names = columns(source_table).map(&:name)

        trigger_set = StrataTriggerSetDefinition.new(source_table, history_table, column_names)

        execute schema_creation.accept(trigger_set)
      end

      def drop_history_triggers(source_table)
        %i[insert update delete].each do |verb|
          function_name = history_callback_function_name(source_table, verb)

          execute "DROP FUNCTION #{function_name}() CASCADE"
        end
      end

      def history_callback_function_name(table_name, verb)
        identifier = "#{table_name}_#{verb}"
        hashed_identifier = Digest::SHA256.hexdigest(identifier).first(10)

        "strata_cb_#{hashed_identifier}"
      end

      def history_table?(table_name)
        results = execute(<<~SQL.squish)
          SELECT 1
          FROM strata_metadata
          WHERE history_table = '#{table_name}'
        SQL

        results.count > 0
      end

      def history_table_for(temporal_table)
        results = execute(<<~SQL.squish)
          SELECT history_table
          FROM strata_metadata
          WHERE temporal_table = '#{temporal_table}'
        SQL

        return if results.count.zero?

        results.first["history_table"]
      end

      def temporal_table_for(history_table)
        results = execute(<<~SQL.squish)
          SELECT temporal_table
          FROM strata_metadata
          WHERE history_table = '#{history_table}'
        SQL

        return if results.count.zero?

        results.first["temporal_table"]
      end

      private

      def register_history_table(history_table, temporal_table)
        conn.execute(<<~SQL)
          INSERT INTO strata_metadata (history_table, temporal_table)
          VALUES ('#{history_table}', '#{temporal_table}')
        SQL
      end

      def unregister_history_table(history_table, temporal_table)
        conn.execute(<<~SQL)
          DELETE FROM strata_metadata
          WHERE history_table = '#{history_table}'
            AND temporal_table = '#{temporal_table}'
        SQL
      end

      def copy_data(source_table, history_table, columns, options)
        fields = columns.map(&:name).join(", ")

        sys_period_start = if options.is_a?(Hash) && options[:epoch_time]
          "'#{options[:epoch_time].utc.iso8601}'"
        else
          "NULL"
        end

        execute(<<~SQL.squish)
          INSERT INTO #{quote_table_name(history_table)} (#{fields}, sys_period)
          SELECT #{fields}, tstzrange(#{sys_period_start}, NULL)
          FROM #{quote_table_name(source_table)};
        SQL
      end
    end
  end
end
