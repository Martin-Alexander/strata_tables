require_relative "strata_tables/connection_adapters/schema_creation"
require_relative "strata_tables/connection_adapters/schema_definitions"
require_relative "strata_tables/connection_adapters/schema_statements"
require_relative "strata_tables/migration/command_recorder"
require_relative "strata_tables/snapshot_builder"

module StrataTables
  def snapshot(ar_class, time)
    SnapshotBuilder.build(ar_class, time)
  end
end

ActiveRecord::ConnectionAdapters::AbstractAdapter.include StrataTables::ConnectionAdapters::SchemaStatements
ActiveRecord::Migration::CommandRecorder.include StrataTables::Migration::CommandRecorder
