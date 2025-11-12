module ActiveRecord::Temporal::AsOfQuery
  class PredicateBuilder
    class ContainsHandler
      def initialize(predicate_builder)
        @predicate_builder = predicate_builder
      end

      def call(attribute, value)
        time_as_tstz = Arel::Nodes::As.new(
          Arel::Nodes::Quoted.new(value.time),
          Arel::Nodes::SqlLiteral.new("timestamptz")
        )

        cast_value = Arel::Nodes::NamedFunction.new("CAST", [time_as_tstz])

        attribute.contains(cast_value)
      end

      private

      attr_reader :predicate_builder
    end
  end
end
