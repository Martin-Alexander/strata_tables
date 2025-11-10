require "active_support"

require_relative "strata_tables/application_versioning"
require_relative "strata_tables/as_of"
require_relative "strata_tables/temporal_query_registry"
require_relative "strata_tables/connection_adapters/schema_creation"
require_relative "strata_tables/connection_adapters/schema_definitions"
require_relative "strata_tables/connection_adapters/schema_statements"
require_relative "strata_tables/patches/association_reflection"
require_relative "strata_tables/patches/command_recorder"
require_relative "strata_tables/patches/join_dependency"
require_relative "strata_tables/patches/merger"
require_relative "strata_tables/patches/relation"
require_relative "strata_tables/patches/through_association"
require_relative "strata_tables/system_versioning"

ActiveSupport.on_load(:active_record) do
  require "active_record/connection_adapters/postgresql_adapter" # TODO: add test

  ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.prepend(StrataTables::ConnectionAdapters::SchemaStatements)

  [
    [
      ActiveRecord::Associations::Preloader::ThroughAssociation,
      StrataTables::Patches::ThroughAssociation
    ],
    [
      ActiveRecord::Migration::CommandRecorder,
      StrataTables::Patches::CommandRecorder
    ],
    [
      ActiveRecord::Reflection::AssociationReflection,
      StrataTables::Patches::AssociationReflection
    ],
    [
      ActiveRecord::Relation,
      StrataTables::Patches::Relation
    ],
    [
      ActiveRecord::Relation::Merger,
      StrataTables::Patches::Merger
    ],
    [
      ActiveRecord::Associations::JoinDependency,
      StrataTables::Patches::JoinDependency
    ]
  ].each { |(base, patch)| base.prepend(patch) }
end
