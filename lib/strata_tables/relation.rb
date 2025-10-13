module StrataTables
  module Relation
    def as_of(time)
      spawn.as_of!(time)
    end

    def as_of!(time)
      if time && table_name.end_with?("_versions")
        where!("#{table_name}.validity @> ?::timestamptz", time)
      end

      self.as_of_value = time
      self
    end

    def _as_of(time)
      spawn._as_of!(time)
    end

    def _as_of!(time)
      self.as_of_value = time
      self
    end

    def as_of_value
      @values.fetch(:as_of, nil)
    end

    def as_of_value=(value)
      # assert_modifiable!
      @values[:as_of] = value
    end

    def build_joins(*, **, &block)
      join_sources = super

      add_validity_constraint(join_sources) if as_of_value

      join_sources
    end

    def instantiate_records(*, **, &block)
      super.tap do |records|
        records.each do |record|
          record.as_of_value = as_of_value if record.respond_to?(:as_of_value=)

          walk_associations(record, includes_values | eager_load_values) do |record, assoc_name|
            reflection = record.class.reflect_on_association(assoc_name)
            next unless reflection

            assoc = record.association(assoc_name)
            target = assoc.target

            if target.is_a?(Array)
              target.each do |t|
                t.respond_to?(:as_of_value=) && t.as_of_value = as_of_value
              end
            else
              target.respond_to?(:as_of_value=) && target.as_of_value = as_of_value
            end
          end
        end
      end
    end

    private

    def add_validity_constraint(joins)
      timestamp = Arel::Nodes::NamedFunction.new(
        "CAST",
        [Arel::Nodes::As.new(
          Arel::Nodes::Quoted.new(as_of_value),
          Arel::Nodes::SqlLiteral.new("timestamptz")
        )]
      )

      joins.each do |join|
        on_expr = join.right.expr

        if on_expr.is_a?(Arel::Nodes::Nary)
          on_expr.children.map! do |child|
            if child.respond_to?(:strata_tag)
              join.left[:validity].contains(timestamp)
            else
              child
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
        node.each do |parent, child|
          block.call(record, parent)

          walk_associations(record, child, &block)
        end
      end
    end
  end
end
