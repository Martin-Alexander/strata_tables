module ActiveRecord::Temporal
  module Patches
    module Relation
      def time_scope(scope)
        spawn.time_scope!(scope)
      end

      def time_scope!(scope)
        self.time_scope_values = time_scope_values.merge(scope)
        self
      end

      def time_scope_values
        @values.fetch(:time_scope, ActiveRecord::QueryMethods::FROZEN_EMPTY_HASH)
      end

      def time_scope_values=(scope)
        assert_modifiable! # TODO: write test

        @values[:time_scope] = scope
      end

      private

      if ActiveRecord.version > Gem::Version.new("8.0.4")
        def build_arel(connection)
          TemporalQueryRegistry.with_query_scope(time_scope_values) { super }
        end
      else
        def build_arel(connection, aliases = nil)
          TemporalQueryRegistry.with_query_scope(time_scope_values) { super }
        end
      end

      def instantiate_records(rows, &block)
        return super if time_scope_values.empty?

        records = super

        records.each do |record|
          record.initialize_time_scope_from_relation(self) if record.is_a?(AsOf)
        end

        records
      end
    end
  end
end
