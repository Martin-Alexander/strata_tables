module ActiveRecord::Temporal
  module Patches
    module ThroughAssociation
      def through_scope
        super.tap do |scope|
          scope.time_scope_values = reflection_scope.time_scope_values
        end
      end
    end
  end
end
