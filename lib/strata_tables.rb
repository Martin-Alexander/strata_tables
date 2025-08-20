require_relative "strata_tables/connection_adapters/schema_creation"
require_relative "strata_tables/connection_adapters/schema_definitions"
require_relative "strata_tables/connection_adapters/schema_statements"
require_relative "strata_tables/migration/command_recorder"
require_relative "strata_tables/models/version"
require_relative "strata_tables/model"
require_relative "strata_tables/snapshot"
require_relative "strata_tables/snapshots/builder"
require_relative "strata_tables/snapshots/display"

module StrataTables
  def snapshot(ar_class, time)
    Snapshots::Builder.build(ar_class, time)
  end

  def as_of_scope(time)
    Thread.current[:strata_tables_as_of_time] = time

    yield
  ensure
    Thread.current[:strata_tables_as_of_time] = nil
  end
end

ActiveRecord::ConnectionAdapters::AbstractAdapter.include StrataTables::ConnectionAdapters::SchemaStatements
ActiveRecord::Migration::CommandRecorder.include StrataTables::Migration::CommandRecorder
