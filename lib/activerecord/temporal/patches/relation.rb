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
        super.tap do |records|
          records.each do |record|
            set_time_scopes(record)

            walk_associations(record, includes_values | eager_load_values) do |record, assoc_name|
              reflection = record.class.reflect_on_association(assoc_name)
              next unless reflection

              assoc = record.association(assoc_name)
              target = assoc.target

              if target.is_a?(Array)
                target.each do |t|
                  set_time_scopes(t)
                end
              else
                set_time_scopes(target)
              end
            end
          end
        end
      end

      def walk_associations(record, node, &block)
        case node
        when Symbol, String
          block.call(record, node)
        when Array
          node.each { |child| walk_associations(record, child, &block) }
        when Hash
          # TODO: Write tests

          node.each do |parent, child|
            block.call(record, parent)

            walk_associations(record, child, &block)
          end
        end
      end

      def set_time_scopes(record)
        return unless record.respond_to?(:time_scopes=)

        record.time_scopes = time_scope_values
      end
    end
  end
end
