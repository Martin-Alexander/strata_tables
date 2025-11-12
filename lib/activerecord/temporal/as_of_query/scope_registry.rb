module ActiveRecord::Temporal
  module AsOfQuery
    class ScopeRegistry
      class << self
        delegate :ambient_time_constraints,
          :association_time_constraints,
          :association_time_scopes,
          :with_ambient_time_constraints,
          :for_associations,
          :at,
          to: :instance

        def instance
          ActiveSupport::IsolatedExecutionState[:temporal_as_of_query_registry] ||= new
        end
      end

      def initialize
        @ambient_time_constraints = {}
        @association_time_constraints = {}
        @association_time_scopes = {}
      end

      def ambient_time_constraints(dimensions = nil)
        return @ambient_time_constraints unless dimensions

        @ambient_time_constraints.slice(*dimensions)
      end

      def association_time_constraints(dimensions)
        default_association_time_constraints(dimensions)
          .merge(@ambient_time_constraints.slice(*dimensions))
          .merge(@association_time_constraints.slice(*dimensions))
      end

      def association_time_scopes(dimensions)
        @association_time_scopes.slice(*dimensions)
      end

      def with_ambient_time_constraints(time_constraints, &block)
        original = @ambient_time_constraints.dup

        @ambient_time_constraints = time_constraints

        block.call
      ensure
        @ambient_time_constraints = original
      end

      def at(time_constraints, &block)
        with_ambient_time_constraints(time_constraints, &block)
      end

      def for_associations(time_scopes, &block)
        original_time_scopes = @association_time_scopes.dup
        original_time_constraints = @association_time_constraints.dup

        @association_time_scopes = @association_time_scopes.merge(time_scopes)
        @association_time_constraints = @association_time_constraints.merge(time_scopes)

        block.call
      ensure
        @association_time_scopes = original_time_scopes
        @association_time_constraints = original_time_constraints
      end

      private

      def default_association_time_constraints(dimensions)
        dimensions.map { |dimension| [dimension, Time.current] }.to_h
      end
    end
  end
end
