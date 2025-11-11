module ActiveRecord::Temporal
  module AsOfQuery
    class RangeError < StandardError; end

    extend ActiveSupport::Concern

    class_methods do
      def existed_at_constraint(arel_table, time, time_dimension)
        time_f = time.utc.strftime("%Y-%m-%d %H:%M:%S.%6N")

        <<~SQL
          "#{arel_table.name}"."#{time_dimension}" @> '#{time_f}'::timestamptz
        SQL
      end

      def temporal_association_scope(&block)
        AssociationScope.build(block)
      end

      def resolve_time_scopes(time_or_time_scopes)
        return time_or_time_scopes if time_or_time_scopes.is_a?(Hash)

        {default_time_dimension.to_sym => time_or_time_scopes}
      end
    end

    included do
      include AssociationMacros
      include TimeDimensions

      delegate :resolve_time_scopes, to: :class

      scope :as_of, ->(time) do
        time_scopes = resolve_time_scopes(time)

        existed_at(time_scopes).time_scope(time_scopes)
      end

      scope :existed_at, ->(time) do
        time_scopes = resolve_time_scopes(time)

        rel = all

        time_scopes.each do |time_dimension, time|
          next unless time_dimension_column?(time_dimension)

          rel = rel.where(existed_at_constraint(table, time, time_dimension))
        end

        rel
      end
    end

    def time_scopes
      @time_scopes || {}
    end

    def time_scopes=(value)
      @time_scopes = value&.slice(*time_dimensions)
    end

    def time_scope
      time_scopes[default_time_dimension]
    end

    def time_scopes_for(time_dimensions)
      time_scopes.slice(*time_dimensions)
    end

    def as_of!(time)
      time_scopes = resolve_time_scopes(time)

      ensure_time_scopes_in_bounds!(time_scopes)

      reload

      self.time_scopes = time_scopes
    end

    def as_of(time)
      time_scopes = resolve_time_scopes(time)

      self.class.as_of(time_scopes).find_by(self.class.primary_key => [id])
    end

    def initialize_time_scope_from_relation(relation)
      associations = relation.includes_values | relation.eager_load_values

      self.time_scopes = relation.time_scope_values

      AssociationWalker.each_target(self, associations) do |target|
        target.time_scopes = relation.time_scope_values
      end
    end

    private

    def ensure_time_scopes_in_bounds!(time_scopes)
      time_scopes.each do |dimension, time|
        if time_dimension_column?(dimension) && !time_dimension(dimension).cover?(time)
          raise RangeError, "#{time} is outside of '#{dimension}' range"
        end
      end
    end
  end
end
