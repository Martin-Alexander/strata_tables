module ActiveRecord::Temporal
  module Patches
    module Relation
      private

      if ActiveRecord.version > Gem::Version.new("8.0.4")
        def build_arel(aliases)
          AsOfQuery::ScopeRegistry.for_associations(time_scope_values) do
            super
          end
        end
      else
        def build_arel(aliases, connection = nil)
          AsOfQuery::ScopeRegistry.for_associations(time_scope_values) do
            super
          end
        end
      end

      def instantiate_records(rows, &block)
        return super if time_scope_values.empty?

        records = super

        records.each do |record|
          record.initialize_time_scope_from_relation(self) if record.is_a?(AsOfQuery)
        end

        records
      end
    end
  end
end
