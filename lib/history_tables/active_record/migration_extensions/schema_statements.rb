module HistoryTables
  module ActiveRecord
    module MigrationExtensions
      module SchemaStatements
        def create_history_table(table_name, **options, &block)
          create_table(table_name, **options, &block)
        end
      end
    end
  end
end

ActiveRecord::ConnectionAdapters::AbstractAdapter.include HistoryTables::ActiveRecord::MigrationExtensions::SchemaStatements
