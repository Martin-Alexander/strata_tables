module StrataTables
  module ArelNodes
    class ExistedAt < Arel::Nodes::Contains
      def initialize(attribute, time)
        time_as_tstz = Arel::Nodes::As.new(
          Arel::Nodes::Quoted.new(time),
          Arel::Nodes::SqlLiteral.new("timestamptz")
        )

        time_casted = Arel::Nodes::NamedFunction.new("CAST", [time_as_tstz])

        super(attribute, time_casted)
      end
    end
  end
end
