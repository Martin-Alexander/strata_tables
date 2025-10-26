module StrataTables
  module Relation
    module Merger
      def merge
        super

        relation.as_of_timestamp!(values[:as_of_timestamp] || {})

        relation
      end
    end
  end
end
