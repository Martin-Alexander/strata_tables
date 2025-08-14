require_relative "strata_tables/associations/builder/belongs_to"
require_relative "strata_tables/associations/builder/has_many"
require_relative "strata_tables/reflection"
require_relative "strata_tables/migration/command_recorder"
require_relative "strata_tables/schema_creation"
require_relative "strata_tables/schema_definitions"
require_relative "strata_tables/schema_statements"
require_relative "strata_tables/snapshot_builder"

module StrataTables
  def snapshot(ar_class, time)
    SnapshotterBuilder.build(ar_class, time)
  end
end

ActiveRecord::ConnectionAdapters::AbstractAdapter.include StrataTables::SchemaStatements
ActiveRecord::Migration::CommandRecorder.include StrataTables::CommandRecorder
