module StrataTables
  module ConnectionAdapters
    module SchemaStatements
      def create_history_table(source_table, **options)
        except = options[:except]&.map(&:to_sym) || []

        source_columns = columns(source_table).reject do |column|
          except.include?(column.name.to_sym)
        end

        history_table = "#{source_table}__history"

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

        if extension_enabled?(:btree_gist)
          add_exclusion_constraint(history_table, "id WITH =, validity WITH &&", using: :gist)
        end

        create_history_triggers(source_table)

        if options[:copy_data]
          copy_data(
            source_table,
            history_table,
            source_columns,
            options[:copy_data]
          )
        end
      end

      def drop_history_table(source_table, **options)
        history_table = "#{source_table}__history"

        drop_table(history_table)

        drop_history_triggers(source_table)
      end

      def create_history_triggers(source_table)
        schema_creation = SchemaCreation.new(self)

        history_table = "#{source_table}__history"
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

      def history_callback_function_name(source_table, verb)
        identifier = "#{source_table}_#{verb}"
        hashed_identifier = Digest::SHA256.hexdigest(identifier).first(10)

        "strata_cb_#{hashed_identifier}"
      end

      private

      def copy_data(source_table, history_table, columns, options)
        fields = columns.map(&:name).join(", ")

        validity_start = if options.is_a?(Hash) && options[:epoch_time]
          "'#{options[:epoch_time].utc.iso8601}'"
        else
          "NULL"
        end

        execute(<<~SQL.squish)
          INSERT INTO #{quote_table_name(history_table)} (#{fields}, validity)
          SELECT #{fields}, tstzrange(#{validity_start}, NULL)
          FROM #{quote_table_name(source_table)};
        SQL
      end
    end
  end
end
