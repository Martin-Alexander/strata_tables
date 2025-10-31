module StrataTables
  module AsOf
    class RangeError < StandardError; end

    extend ActiveSupport::Concern

    class_methods do
      def as_of_attribute=(column)
        attr_accessor "#{column}_as_of"

        @as_of_attribute = column.to_sym
      end

      def as_of_attribute
        @as_of_attribute
      end

      def as_of_column_exists?
        @as_of_column_exists ||= as_of_attribute &&
          connection.column_exists?(table_name, as_of_attribute)
      end

      def extant_constraint(table, attribute)
        Arel::Nodes::NamedFunction.new("upper_inf", [table[attribute]])
      end

      def existed_at_constraint(table, time, attribute)
        time_as_tstz = Arel::Nodes::As.new(
          Arel::Nodes::Quoted.new(time),
          Arel::Nodes::SqlLiteral.new("timestamptz")
        )

        time_casted = Arel::Nodes::NamedFunction.new("CAST", [time_as_tstz])

        Arel::Nodes::Contains.new(table[attribute], time_casted)
      end

      def temporal_association_scope(&merge_scope)
        scope = if merge_scope
          if merge_scope.arity == 0
            ->(owner = nil) do
              base_scope = instance_exec(&merge_scope)

              as_of_time = owner&.send("#{as_of_attribute}_as_of") ||
                AsOfRegistry.timestamps[as_of_attribute]

              as_of_time ? base_scope.as_of(as_of_time) : base_scope.extant
            end
          else
            ->(owner) do
              base_scope = instance_exec(owner, &merge_scope)

              as_of_time = owner&.send("#{as_of_attribute}_as_of") ||
                AsOfRegistry.timestamps[as_of_attribute]

              as_of_time ? base_scope.as_of(as_of_time) : base_scope.extant
            end
          end
        else
          ->(owner = nil) do
            as_of_time = owner&.send("#{as_of_attribute}_as_of") ||
              AsOfRegistry.timestamps[as_of_attribute]

            as_of_time ? as_of(as_of_time) : extant
          end
        end

        def scope.as_of_scope? = true

        scope
      end
    end

    included do
      scope :as_of, ->(time) do
        existed_at(time).as_of_timestamp(as_of_attribute => time)
      end

      scope :existed_at, ->(time) do
        return unless as_of_column_exists?

        where(existed_at_constraint(table, time, as_of_attribute))
      end

      scope :extant, -> do
        return unless as_of_column_exists?

        where(extant_constraint(table, as_of_attribute))
      end
    end

    def as_of!(time)
      as_of_attribute = self.class.as_of_attribute

      if self.class.as_of_column_exists? && !send(as_of_attribute).cover?(time)
        raise RangeError, "#{time} is outside of '#{as_of_attribute}' range"
      end

      reload

      send("#{as_of_attribute}_as_of=", time)
    end

    def as_of(time)
      self.class.as_of(time).find_by(self.class.primary_key => id)
    end
  end
end
