require "active_support"

require_relative "strata_tables/as_of"
require_relative "strata_tables/as_of_registry"
require_relative "strata_tables/associations/preloader/through_association"
require_relative "strata_tables/connection_adapters/schema_creation"
require_relative "strata_tables/connection_adapters/schema_definitions"
require_relative "strata_tables/connection_adapters/schema_statements"
require_relative "strata_tables/migration/command_recorder"
require_relative "strata_tables/model"
require_relative "strata_tables/reflection/association_reflection"
require_relative "strata_tables/relation"
require_relative "strata_tables/relation/merger"
require_relative "strata_tables/version_model"

ActiveSupport.on_load(:active_record) do
  begin
    require "active_record/connection_adapters/postgresql_adapter"
  rescue LoadError
  end

  if defined? ActiveRecord::ConnectionAdapters::PostgreSQLAdapter
    ActiveRecord::Associations::Preloader::ThroughAssociation.prepend StrataTables::Associations::Preloader::ThroughAssociation
    ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.include StrataTables::ConnectionAdapters::SchemaStatements
    ActiveRecord::Migration::CommandRecorder.include StrataTables::Migration::CommandRecorder
    ActiveRecord::Reflection::AssociationReflection.prepend StrataTables::Reflection::AssociationReflection
    ActiveRecord::Relation.prepend StrataTables::Relation
    ActiveRecord::Relation::Merger.prepend StrataTables::Relation::Merger
  end
end
