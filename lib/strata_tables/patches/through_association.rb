module StrataTables
  module Patches
    module ThroughAssociation
      def through_scope
        super.tap do |scope|
          scope.as_of_timestamp_values = reflection_scope.as_of_timestamp_values
        end
      end
    end
  end
end
