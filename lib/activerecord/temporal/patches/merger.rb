module ActiveRecord::Temporal
  module Patches
    module Merger
      def merge
        super.tap do |relation|
          relation.time_scope!(values[:time_scope] || {})
        end
      end
    end
  end
end
