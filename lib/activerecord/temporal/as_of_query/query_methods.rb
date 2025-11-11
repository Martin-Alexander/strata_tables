module ActiveRecord::Temporal
  module AsOfQuery
    module QueryMethods
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
    end
  end
end
