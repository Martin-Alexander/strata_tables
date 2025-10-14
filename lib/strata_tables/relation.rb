module StrataTables
  module Relation
    def as_of(time)
      spawn.as_of!(time)
    end

    def as_of!(time)
      scope_by_time!(time) if model.history_table?

      self.as_of_value = time
      self
    end

    def as_of_value
      @values.fetch(:as_of, nil)
    end

    def as_of_value=(value)
      # TODO: add tests for: assert_modifiable!

      @values[:as_of] = value
    end

    private

    def scope_by_time!(time)
      node = if time
        ArelNodes::ExistedAt.new(arel_table[:validity], time)
      else
        ArelNodes::Extant.new(arel_table[:validity])
      end

      where!(node)
    end

    def build_joins(join_sources, aliases = nil)
      super.tap do |joins|
        add_validity_constraint(joins) if as_of_value
      end
    end

    def instantiate_records(rows, &block)
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

    def add_validity_constraint(joins)
      joins.each do |join|
        walk_arel_nodes(join.right.expr) do |node, parent, relationship|
          next unless node.is_a?(ArelNodes::Extant)

          new_node = ArelNodes::ExistedAt.new(join.left[:validity], as_of_value)

          case relationship
          when :left
            parent.left = new_node
          when :right
            parent.right = new_node
          when Integer
            parent.children[relationship] = new_node
          when :value
            parent.value = new_node
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

    def walk_arel_nodes(node, parent = nil, relationship = nil, &block)
      case node
      when Arel::Nodes::Unary
        # TODO: Write tests

        walk_arel_nodes(node.value, node, :value & block)
      when Arel::Nodes::Binary
        # TODO: Write tests

        walk_arel_nodes(node.left, node, :left, &block)
        walk_arel_nodes(node.right, node, :right, &block)
      when Arel::Nodes::Nary
        node.children.each_with_index do |child, index|
          walk_arel_nodes(child, node, index, &block)
        end
      else
        block.call(node, parent, relationship)
      end

      false
    end
  end
end
