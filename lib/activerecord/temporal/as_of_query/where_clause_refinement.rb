module ActiveRecord::Temporal
  module AsOfQuery
    module WhereClauseRefinement
      refine ActiveRecord::Relation::WhereClause do
        def except_contains(columns)
          columns = columns.map(&:to_s)

          remaining_predications = predicates.reject do |node|
            node.is_a?(Arel::Nodes::Contains) && columns.include?(node.left.name)
          end

          self.class.new(remaining_predications)
        end
      end
    end
  end
end
