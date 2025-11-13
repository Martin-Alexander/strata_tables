module ActiveRecord::Temporal
  module Patches
    module Merger
      def merge
        super.tap do |relation|
          relation.time_tags!(values[:time_tags] || {})
        end
      end
    end
  end
end
