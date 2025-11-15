module ActiveRecord::Temporal
  module Patches
    module Relation
      private

      if ActiveRecord.version > Gem::Version.new("8.0.4")
        def build_arel(aliases)
          Querying::Scoping.as_of(time_tag_values) do
            super
          end
        end
      else
        def build_arel(aliases, connection = nil)
          Querying::Scoping.as_of(time_tag_values) do
            super
          end
        end
      end

      def instantiate_records(rows, &block)
        return super if time_tag_values.empty?

        records = super

        records.each do |record|
          record.initialize_time_tags_from_relation(self) if record.is_a?(Querying)
        end

        records
      end
    end
  end
end
