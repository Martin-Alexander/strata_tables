module ActiveRecord::Temporal
  module Querying
    class ScopeRegistry
      class << self
        delegate :global_constraints,
          :association_constraints,
          :association_tags,
          :universal_global_constraint_time,
          :global_constraints=,
          :association_constraints=,
          :association_tags=,
          :universal_global_constraint_time=,
          :global_constraint_for,
          :association_constraint_for,
          :association_tag_for,
          :global_constraints_for,
          :association_constraints_for,
          :association_tags_for,
          :set_global_constraints,
          :set_association_constraints,
          :set_association_tags,
          to: :instance

        def instance
          ActiveSupport::IsolatedExecutionState[:temporal_querying_registry] ||= new
        end
      end

      attr_accessor :global_constraints,
        :association_constraints,
        :association_tags,
        :universal_global_constraint_time

      def initialize(
        global_constraints: nil,
        association_constraints: nil,
        association_tags: nil,
        default_association_constraint_time: nil,
        universal_global_constraint_time: nil
      )
        @global_constraints = global_constraints || {}
        @association_constraints = association_constraints || {}
        @association_tags = association_tags || {}
        @default_association_constraint_time = default_association_constraint_time ||
          -> { Time.current }
        @universal_global_constraint_time = universal_global_constraint_time
      end

      def global_constraint_for(dimension)
        global_constraints[dimension] || universal_global_constraint_time
      end

      def association_constraint_for(dimension)
        association_constraints[dimension] ||
          global_constraint_for(dimension) ||
          @default_association_constraint_time.call
      end

      def association_tag_for(dimension)
        association_tags[dimension]
      end

      def global_constraints_for(*dimensions)
        dimensions.flatten.index_with do |dimension|
          global_constraint_for(dimension)
        end.compact
      end

      def association_constraints_for(*dimensions)
        dimensions.flatten.index_with do |dimension|
          association_constraint_for(dimension)
        end
      end

      def association_tags_for(*dimensions)
        association_tags.slice(*dimensions.flatten)
      end

      def set_global_constraints(time_coords)
        self.global_constraints = global_constraints
          .merge(time_coords)
      end

      def set_association_constraints(time_coords)
        self.association_constraints = association_constraints
          .merge(time_coords)
      end

      def set_association_tags(time_coords)
        self.association_tags = association_tags
          .merge(time_coords)
      end

      # def global_constraints(dimensions = nil)
      #   return @global_constraints unless dimensions

      #   @global_constraints.slice(*dimensions)
      # end

      # def association_constraints(dimensions)
      #   default_association_constraints(dimensions)
      #     .merge(@global_constraints.slice(*dimensions))
      #     .merge(@association_constraints.slice(*dimensions))
      # end

      # def association_tags(dimensions)
      #   @association_tags.slice(*dimensions)
      # end

      def at_time(time_coords, &block)
        original = @global_constraints.dup

        @global_constraints = @global_constraints.merge(time_coords)

        block.call
      ensure
        @global_constraints = original
      end

      def as_of(time_coords, &block)
        original_time_tags = @association_tags.dup
        original_constraints = @association_constraints.dup

        @association_tags = @association_tags.merge(time_coords)
        @association_constraints = @association_constraints.merge(time_coords)

        block.call
      ensure
        @association_tags = original_time_tags
        @association_constraints = original_constraints
      end

      private

      def default_association_constraints(dimensions)
        dimensions.map { |dimension| [dimension, Time.current] }.to_h
      end
    end
  end
end
