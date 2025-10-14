module StrataTables
  module ArelNodes
    class Extant < Arel::Nodes::NamedFunction
      def initialize(attribute)
        super("upper_inf", [attribute])
      end
    end
  end
end
