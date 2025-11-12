module ActiveRecord::Temporal
  module AsOfQuery
    module QueryMethods
      require "activerecord/temporal/as_of_query/where_clause_refinement"

      using AsOfQuery::WhereClauseRefinement

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

      def rewhere_contains(conditions)
        scope = spawn

        scope.where_clause = where_clause.execept_contains(conditions.keys)
        scope.where_clause += build_where_clause(conditions)

        scope
      end
    end
  end
end
