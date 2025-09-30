module StrataTables
  module Relation
    def as_of(time)
      @as_of_time = time

      return all unless connection.column_exists?(table_name, :validity)

      where("#{table_name}.validity @> ?::timestamptz", time)
    end

    def build_joins(*, **)
      joins = super

      timestamp = Arel::Nodes::NamedFunction.new(
        "CAST",
        [Arel::Nodes::As.new(
          Arel::Nodes::Quoted.new(@as_of_time),
          Arel::Nodes::SqlLiteral.new("timestamptz")
        )]
      )

      joins.each do |join|
        next if join.is_a?(Arel::Nodes::StringJoin)
        next unless join.left.name.end_with?("_versions")

        on_node = join.right

        existing_expr = on_node.expr

        on_node.expr = Arel::Nodes::And.new([existing_expr, join.left[:validity].contains(timestamp)])
      end

      joins
    end
  end
end