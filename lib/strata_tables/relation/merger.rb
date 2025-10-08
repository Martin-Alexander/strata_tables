module StrataTables
  module Relation
    module Merger
      def merge
        super

        relation.as_of_value = values[:as_of]

        relation
      end
    end
  end
end
