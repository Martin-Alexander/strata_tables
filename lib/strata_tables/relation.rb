module StrataTables
  module Relation
    def as_of(time)
      @as_of_time = time

      return all unless connection.column_exists?(table_name, :validity)

      where("#{table_name}.validity @> ?::timestamptz", time)
    end

    def build_joins(*, **, &block)
      joins = super

      add_validity_constraint(joins) if @as_of_time

      joins
    end

    def instantiate_records(*, **, &block)
      super.tap do |records|
        next unless @as_of_time

        records.each do |record|
          record._as_of = @as_of_time if record.respond_to?(:_as_of=)
        end
      end
    end

    private

    def add_validity_constraint(joins)
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

        on_node.expr = Arel::Nodes::And.new([
          existing_expr,
          join.left[:validity].contains(timestamp)
        ])
      end
    end
  end
end
