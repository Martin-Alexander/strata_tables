module StrataTables
  module Associations
    module Preloader
      module ThroughAssociation
        def through_scope
          super.tap do |scope|
            scope.as_of_value = reflection_scope.as_of_value
          end
        end
      end
    end
  end
end
