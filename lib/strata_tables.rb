require_relative "strata_tables/connection_adapters/schema_creation"
require_relative "strata_tables/connection_adapters/schema_definitions"
require_relative "strata_tables/connection_adapters/schema_statements"
require_relative "strata_tables/migration/command_recorder"
require_relative "strata_tables/models/version"
require_relative "strata_tables/model"
require_relative "strata_tables/relation"

module StrataTables
  def as_of_scope(time)
    Thread.current[:strata_tables_as_of_time] = time

    yield
  ensure
    Thread.current[:strata_tables_as_of_time] = nil
  end
end

ActiveSupport.on_load(:active_record) do
  begin
    require "active_record/connection_adapters/postgresql_adapter"
  rescue LoadError
  end

  if defined? ActiveRecord::ConnectionAdapters::PostgreSQLAdapter
    ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.include StrataTables::ConnectionAdapters::SchemaStatements
    ActiveRecord::Migration::CommandRecorder.include StrataTables::Migration::CommandRecorder
    ActiveRecord::Relation.include StrataTables::Relation
  end
end
