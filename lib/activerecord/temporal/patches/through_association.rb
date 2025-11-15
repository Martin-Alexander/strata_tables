module ActiveRecord::Temporal
  module Patches
    # Patches the preloader's `through_scope` method to pass along the relation's
    # time tag values when it handles has-many-through associations. The handler
    # for has-many associations uses `Relation#merge`, but this one doesn't.
    module ThroughAssociation
      def through_scope
        super.tap do |scope|
          scope.time_tag_values = reflection_scope.time_tag_values
        end
      end
    end
  end
end
