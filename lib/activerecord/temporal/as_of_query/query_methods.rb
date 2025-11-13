module ActiveRecord::Temporal
  module AsOfQuery
    module QueryMethods
      require "activerecord/temporal/as_of_query/where_clause_refinement"

      using AsOfQuery::WhereClauseRefinement

      def time_tags(scope)
        spawn.time_tags!(scope)
      end

      def time_tags!(scope)
        self.time_tag_values = time_tag_values.merge(scope)
        self
      end

      def time_tag_values
        @values.fetch(:time_tags, ActiveRecord::QueryMethods::FROZEN_EMPTY_HASH)
      end

      def time_tag_values=(scope)
        assert_modifiable! # TODO: write test

        @values[:time_tags] = scope
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
