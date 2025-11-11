require "active_support"

require_relative "temporal/application_versioning"
require_relative "temporal/as_of_query"
require_relative "temporal/as_of_query/association_macros"
require_relative "temporal/as_of_query/association_scope"
require_relative "temporal/as_of_query/association_walker"
require_relative "temporal/as_of_query/scope_registry"
require_relative "temporal/as_of_query/time_dimensions"
require_relative "temporal/patches/association_reflection"
require_relative "temporal/patches/join_dependency"
require_relative "temporal/patches/merger"
require_relative "temporal/patches/relation"
require_relative "temporal/patches/through_association"
require_relative "temporal/system_versioning"
require_relative "temporal/system_versioning/command_recorder"
require_relative "temporal/system_versioning/namespace"
require_relative "temporal/system_versioning/model"
require_relative "temporal/system_versioning/schema_creation"
require_relative "temporal/system_versioning/schema_definitions"
require_relative "temporal/system_versioning/schema_statements"

ActiveSupport.on_load(:active_record) do
  require "active_record/connection_adapters/postgresql_adapter" # TODO: add test

  ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.include(ActiveRecord::Temporal::SystemVersioning::SchemaStatements)
  ActiveRecord::Migration::CommandRecorder.include(ActiveRecord::Temporal::SystemVersioning::CommandRecorder)

  [
    [
      ActiveRecord::Associations::Preloader::ThroughAssociation,
      ActiveRecord::Temporal::Patches::ThroughAssociation
    ],
    [
      ActiveRecord::Reflection::AssociationReflection,
      ActiveRecord::Temporal::Patches::AssociationReflection
    ],
    [
      ActiveRecord::Relation,
      ActiveRecord::Temporal::Patches::Relation
    ],
    [
      ActiveRecord::Relation::Merger,
      ActiveRecord::Temporal::Patches::Merger
    ],
    [
      ActiveRecord::Associations::JoinDependency,
      ActiveRecord::Temporal::Patches::JoinDependency
    ]
  ].each { |(base, patch)| base.prepend(patch) }
end
