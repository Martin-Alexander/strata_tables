module ActiveRecord::Temporal
  module AsOfQuery
    class AssociationScope
      class << self
        def build(block)
          scope = build_scope(block)

          def scope.as_of_scope? = true

          scope
        end

        private

        def build_scope(block)
          temporal_scope = build_temporal_scope

          if !block
            return ->(owner = nil) do
              instance_exec(owner, all, &temporal_scope)
            end
          end

          if block.arity != 0
            return ->(owner) do
              base = instance_exec(owner, &block)
              instance_exec(owner, base, &temporal_scope)
            end
          end

          ->(owner = nil) do
            base = instance_exec(owner, &block)
            instance_exec(owner, base, &temporal_scope)
          end
        end

        def build_temporal_scope
          ->(owner, base) do
            time_constraints = ScopeRegistry
              .association_time_constraints(time_dimensions)

            time_scopes = ScopeRegistry
              .association_time_scopes(time_dimensions)

            owner_time_scopes = owner&.time_scopes_for(time_dimensions) || {}

            base
              .existed_at(time_constraints.merge(owner_time_scopes))
              .time_scope(owner_time_scopes.merge(time_scopes))
          end
        end
      end
    end
  end
end
