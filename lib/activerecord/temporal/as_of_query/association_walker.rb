module ActiveRecord::Temporal
  module AsOfQuery
    class AssociationWalker
      class << self
        def each_target(parent_record, associations, &block)
          walk_nodes(associations) do |association|
            target = parent_record.association(association).target

            next unless target

            if target.is_a?(Array)
              target.each(&block)
            else
              block.call(target)
            end
          end
        end

        private

        def walk_nodes(node, &block)
          case node
          when Symbol, String
            block.call(node)
          when Array
            node.each { |child| walk_nodes(child, &block) }
          when Hash
            # TODO: Write tests

            node.each do |parent, child|
              block.call(parent)

              walk_nodes(child, &block)
            end
          end
        end
      end
    end
  end
end
