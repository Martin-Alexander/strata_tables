require_relative "strata_tables/base"
require_relative "strata_tables/command_recorder"
require_relative "strata_tables/const_missing"
require_relative "strata_tables/schema_creation"
require_relative "strata_tables/schema_definitions"
require_relative "strata_tables/schema_statements"
require_relative "strata_tables/snapshot"
require_relative "strata_tables/snapshotter"

module StrataTables
end

ActiveRecord::ConnectionAdapters::AbstractAdapter.include StrataTables::SchemaStatements
ActiveRecord::Migration::CommandRecorder.include StrataTables::CommandRecorder
