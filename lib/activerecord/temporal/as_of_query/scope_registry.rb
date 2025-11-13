module ActiveRecord::Temporal
  module AsOfQuery
    class ScopeRegistry
      class << self
        delegate :ambient_time_constraints,
          :association_time_constraints,
          :association_time_tags,
          :at_time,
          :as_of,
          to: :instance

        def instance
          ActiveSupport::IsolatedExecutionState[:temporal_as_of_query_registry] ||= new
        end
      end

      def initialize
        @ambient_time_constraints = {}
        @association_time_constraints = {}
        @association_time_tags = {}
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

      def association_time_tags(dimensions)
        @association_time_tags.slice(*dimensions)
      end

      def at_time(time_coords, &block)
        original = @ambient_time_constraints.dup

        @ambient_time_constraints = @ambient_time_constraints.merge(time_coords)

        block.call
      ensure
        @ambient_time_constraints = original
      end

      def as_of(time_coords, &block)
        original_time_tags = @association_time_tags.dup
        original_time_constraints = @association_time_constraints.dup

        @association_time_tags = @association_time_tags.merge(time_coords)
        @association_time_constraints = @association_time_constraints.merge(time_coords)

        block.call
      ensure
        @association_time_tags = original_time_tags
        @association_time_constraints = original_time_constraints
      end

      private

      def default_association_time_constraints(dimensions)
        dimensions.map { |dimension| [dimension, Time.current] }.to_h
      end
    end
  end
end
