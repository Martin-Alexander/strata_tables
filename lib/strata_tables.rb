require_relative "strata_tables/active_record/schema_creation"
require_relative "strata_tables/active_record/schema_definitions"
require_relative "strata_tables/active_record/migration_extensions/schema_statements"
require_relative "strata_tables/active_record/migration_extensions/command_recorder"

module StrataTables
end

ActiveRecord::ConnectionAdapters::AbstractAdapter.include StrataTables::ActiveRecord::SchemaStatements
ActiveRecord::Migration::CommandRecorder.include StrataTables::ActiveRecord::CommandRecorder
