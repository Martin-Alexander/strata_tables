module ActiveRecord::Temporal
  module Patches
    module ThroughAssociation
      def through_scope
        super.tap do |scope|
          scope.time_tag_values = reflection_scope.time_tag_values
        end
      end
    end
  end
end
