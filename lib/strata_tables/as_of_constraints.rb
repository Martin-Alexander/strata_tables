module StrataTables
  module AsOfConstraints
    def extant_constraint(attribute)
      Arel::Nodes::NamedFunction.new("upper_inf", [arel_table[attribute]])
    end

    def existed_at_constraint(time, attribute)
      time_as_tstz = Arel::Nodes::As.new(
        Arel::Nodes::Quoted.new(time),
        Arel::Nodes::SqlLiteral.new("timestamptz")
      )

      time_casted = Arel::Nodes::NamedFunction.new("CAST", [time_as_tstz])

      Arel::Nodes::Contains.new(arel_table[attribute], time_casted)
    end
  end
end
