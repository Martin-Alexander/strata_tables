module StrataTables
  module Relation
    module Merger
      def merge
        super.tap do |relation|
          relation.as_of_timestamp!(values[:as_of_timestamp] || {})
        end
      end
    end
  end
end
