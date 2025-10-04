require_relative "strata_tables/connection_adapters/schema_creation"
require_relative "strata_tables/connection_adapters/schema_definitions"
require_relative "strata_tables/connection_adapters/schema_statements"
require_relative "strata_tables/migration/command_recorder"
require_relative "strata_tables/model"
require_relative "strata_tables/reflection/association_reflection"
require_relative "strata_tables/relation"

ActiveSupport.on_load(:active_record) do
  begin
    require "active_record/connection_adapters/postgresql_adapter"
  rescue LoadError
  end

  if defined? ActiveRecord::ConnectionAdapters::PostgreSQLAdapter
    ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.include StrataTables::ConnectionAdapters::SchemaStatements
    ActiveRecord::Migration::CommandRecorder.include StrataTables::Migration::CommandRecorder
    ActiveRecord::Relation.prepend StrataTables::Relation
    ActiveRecord::Reflection::AssociationReflection.prepend StrataTables::Reflection::AssociationReflection
  end
end
