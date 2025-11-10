module ActiveRecord::Temporal
  module ConnectionAdapters
    module SchemaStatements
      include ConnectionAdapters

      def create_versioning_hook(source_table, history_table, columns:)
        ensure_columns_match!(source_table, history_table, columns)

        schema_creation = SchemaCreation.new(self)

        hook_definition = VersioningHookDefinition.new(source_table, history_table, columns)

        execute schema_creation.accept(hook_definition)
      end

      def drop_versioning_hook(source_table, history_table, columns: nil)
        %i[insert update delete].each do |verb|
          function_name = versioning_function_name(source_table, verb)

          execute "DROP FUNCTION #{function_name}() CASCADE"
        end
      end

      def versioning_hook(source_table)
        insert_function_name = versioning_function_name(source_table, :insert)

        row = execute(<<~SQL.squish).first
          SELECT
            pg_proc.proname as function_name,
            obj_description(pg_proc.oid, 'pg_proc') as comment
          FROM pg_proc
          JOIN pg_namespace ON pg_proc.pronamespace = pg_namespace.oid
          WHERE pg_namespace.nspname NOT IN ('pg_catalog', 'information_schema')
            AND pg_proc.proname = '#{insert_function_name}'
        SQL

        return unless row

        metadata = JSON.parse(row["comment"])

        VersioningHookDefinition.new(
          metadata["source_table"].to_sym,
          metadata["history_table"].to_sym,
          metadata["columns"].map(&:to_sym)
        )
      end

      def change_versioning_hook(source_table, history_table, options)
        add_columns = options[:add_columns] || []
        remove_columns = options[:remove_columns] || []

        hook_definition = versioning_hook(source_table)

        ensure_columns_match!(source_table, history_table, add_columns)
        ensure_hook_has_columns!(hook_definition, remove_columns)

        drop_versioning_hook(source_table, history_table)

        new_columns = hook_definition.columns + add_columns - remove_columns

        create_versioning_hook(source_table, history_table, columns: new_columns)
      end

      def history_table(source_table)
        hook_definition = versioning_hook(source_table)

        hook_definition&.history_table
      end

      def versioning_function_name(source_table, verb)
        identifier = "#{source_table}_#{verb}"
        hashed_identifier = Digest::SHA256.hexdigest(identifier).first(10)

        "sys_ver_func_#{hashed_identifier}"
      end

      private

      def ensure_columns_match!(source_table, history_table, column_names)
        source_columns = columns(source_table)
        history_columns = columns(history_table)

        column_names.each do |column_name|
          source_column = source_columns.find { _1.name == column_name.to_s }
          history_column = history_columns.find { _1.name == column_name.to_s }

          if source_column.nil?
            raise ArgumentError, "table '#{source_table}' does not have column '#{column_name}'"
          end

          if history_column.nil?
            raise ArgumentError, "table '#{history_table}' does not have column '#{column_name}'"
          end

          if source_column.type != history_column.type
            raise ArgumentError, "table '#{history_table}' does not have column '#{column_name}' of type '#{source_column.type}'"
          end
        end
      end

      def ensure_hook_has_columns!(hook, column_names)
        column_names.each do |column_name|
          next if hook.columns.include?(column_name)

          raise ArgumentError, "versioning hook between '#{hook.source_table}' and '#{hook.history_table}' does not have column '#{column_name}'"
        end
      end
    end
  end
end
