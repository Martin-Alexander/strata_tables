require "active_support"

require_relative "temporal/application_versioning"
require_relative "temporal/as_of"
require_relative "temporal/association_walker"
require_relative "temporal/temporal_query_registry"
require_relative "temporal/connection_adapters/schema_creation"
require_relative "temporal/connection_adapters/schema_definitions"
require_relative "temporal/connection_adapters/schema_statements"
require_relative "temporal/patches/association_reflection"
require_relative "temporal/patches/command_recorder"
require_relative "temporal/patches/join_dependency"
require_relative "temporal/patches/merger"
require_relative "temporal/patches/relation"
require_relative "temporal/patches/through_association"
require_relative "temporal/system_versioning"

ActiveSupport.on_load(:active_record) do
  require "active_record/connection_adapters/postgresql_adapter" # TODO: add test

  ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.prepend(ActiveRecord::Temporal::ConnectionAdapters::SchemaStatements)

  [
    [
      ActiveRecord::Associations::Preloader::ThroughAssociation,
      ActiveRecord::Temporal::Patches::ThroughAssociation
    ],
    [
      ActiveRecord::Migration::CommandRecorder,
      ActiveRecord::Temporal::Patches::CommandRecorder
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
