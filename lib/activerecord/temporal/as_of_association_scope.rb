module ActiveRecord::Temporal
  class AsOfAssociationScope
    class << self
      def build(block)
        scope = build_scope(block || default_base_scope)

        def scope.as_of_scope? = true

        scope
      end

      private

      def build_scope(block)
        temporal_scope = build_temporal_scope

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
          time_scopes = TemporalQueryRegistry.query_scope_for(time_dimensions)
          owner_time_scopes = owner&.time_scopes_for(time_dimensions)

          time_scopes.merge!(owner_time_scopes) if owner_time_scopes

          default_time_scopes = time_dimensions.map do |dimension|
            [dimension, Time.current]
          end.to_h

          time_scope_constraints = default_time_scopes.merge(time_scopes)

          base.existed_at(time_scope_constraints).time_scope(time_scopes)
        end
      end

      def default_base_scope
        proc { all }
      end
    end
  end
end
