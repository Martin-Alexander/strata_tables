module ActiveRecord::Temporal
  module AsOf
    class RangeError < StandardError; end

    extend ActiveSupport::Concern

    class_methods do
      def set_time_dimensions(*dimensions)
        define_singleton_method(:time_dimensions) { dimensions }
        define_singleton_method(:default_time_dimension) { dimensions.first }
      end

      def time_dimensions = []
      def default_time_dimension = nil

      def time_dimension_column?(time_dimension)
        connection.column_exists?(table_name, time_dimension)
      end

      def existed_at_constraint(arel_table, time, time_dimension)
        time_f = time.utc.strftime("%Y-%m-%d %H:%M:%S.%6N")

        <<~SQL
          "#{arel_table.name}"."#{time_dimension}" @> '#{time_f}'::timestamptz
        SQL
      end

      def temporal_association_scope(&block)
        scope = build_temporal_scope(&block)

        def scope.as_of_scope? = true

        scope
      end

      def resolve_time_scopes(time_or_time_scopes)
        return time_or_time_scopes if time_or_time_scopes.is_a?(Hash)

        {default_time_dimension.to_sym => time_or_time_scopes}
      end

      private

      def build_temporal_scope(&block)
        temporalize = ->(owner = nil, base_scope) do
          time_scopes = TemporalQueryRegistry.query_scope_for(time_dimensions)
          owner_time_scopes = owner&.time_scopes_for(time_dimensions)

          time_scopes.merge!(owner_time_scopes) if owner_time_scopes

          base_scope
            .existed_at(default_association_time_predicates.merge(time_scopes))
            .time_scope(time_scopes)
        end

        if !block
          return ->(owner = nil) { temporalize.call(owner, all) }
        end

        if block.arity != 0
          return ->(owner) { temporalize.call(owner, instance_exec(owner, &block)) }
        end

        ->(owner = nil) { temporalize.call(owner, instance_exec(owner, &block)) }
      end

      def default_association_time_predicates
        time_dimensions.map do |dimension|
          [dimension, Time.current]
        end.to_h
      end
    end

    included do
      delegate :time_dimensions,
        :default_time_dimension,
        :time_dimension_column?,
        :resolve_time_scopes,
        to: :class

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

    def time_dimension(dimension = nil)
      dimension ||= default_time_dimension

      if !time_dimension_column?(dimension)
        raise ArgumentError, "no time dimension column '#{dimension}'"
      end

      send(dimension)
    end

    def time_dimension_start(dimension = nil)
      time_dimension(dimension)&.begin
    end

    def time_dimension_end(dimension = nil)
      time_dimension(dimension)&.end
    end

    def set_time_dimension(value, dimension = nil)
      dimension ||= default_time_dimension

      if !time_dimension_column?(dimension)
        raise ArgumentError, "no time dimension column '#{dimension}'"
      end

      send("#{dimension}=", value)
    end

    def set_time_dimension_start(value, dimension = nil)
      existing_value = time_dimension(dimension)

      new_value = existing_value ? value...existing_value.end : value...nil

      set_time_dimension(new_value, dimension)
    end

    def set_time_dimension_end(value, dimension = nil)
      existing_value = time_dimension(dimension)

      new_value = existing_value ? existing_value.begin...value : nil...value

      set_time_dimension(new_value, dimension)
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
