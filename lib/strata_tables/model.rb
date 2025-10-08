module StrataTables
  module Model
    extend ActiveSupport::Concern

    included do
      reversionify
    end

    class_methods do
      def reversionify(base = nil)
        StrataTables::Model.versionify(self, base || superclass)
      end

      def version_table_backing?
        table_name.end_with?("_versions")
      end
    end

    def validity_start
      return validity.begin if respond_to?(:validity)
    end

    def validity_end
      return validity.end if respond_to?(:validity)
    end

    def as_of_value=(time)
      @as_of_value = time
    end

    def as_of_value
      @as_of_value
    end

    def as_of(time)
      as_of!(time) unless respond_to?(:validity) && !validity.cover?(time)
    end

    def as_of!(time)
      self.as_of_value = time
      self
    end

    module_function

    def versionify(klass, base)
      versionfiy_table_name(klass, base)
      versionfiy_associations(klass, base)
      versionify_primary_key(klass, base)

      base.define_singleton_method(:version) do
        klass
      end
    end

    def versionfiy_table_name(klass, base)
      if version_table_exists?(base)
        klass.table_name = "#{base.table_name}_versions"
      end
    end

    def versionify_primary_key(klass, base)
      if version_table_exists?(base)
        klass.primary_key = :version_id
      end
    end

    def versionfiy_associations(klass, base)
      base.reflect_on_all_associations.each do |reflection|
        options = {
          primary_key: reflection.klass.primary_key,
          foreign_key: reflection.foreign_key,
          class_name: "#{reflection.klass.name}::Version"
        }

        # options[:disable_joins] = true if reflection.is_a?(ActiveRecord::Reflection::ThroughReflection)

        klass.send(
          reflection.macro,
          reflection.name,
          ->(owner = nil) do
            scope = reflection.scope ? instance_exec(owner, &reflection.scope) : all

            if !reflection.klass.version.version_table_backing?
              if owner&.as_of_value
                return scope.as_of(owner.as_of_value)
              else
                return scope
              end
            end

            assoc_table = reflection.klass.version.table_name

            if owner
              if owner.as_of_value
                scope.as_of(owner.as_of_value)
              elsif owner.respond_to?(:validity) && owner.validity_end
                scope.where("#{assoc_table}.validity @> ?::timestamptz", owner.validity_end)
              else
                scope.where("upper_inf(#{assoc_table}.validity)")
              end
            else
              upper = ->(arg) do
                Arel::Nodes::NamedFunction.new("upper", [arg])
              end

              upper_inf = ->(arg) do
                Arel::Nodes::NamedFunction.new("upper_inf", [arg])
              end

              new_table = reflection.klass.version.arel_table
              own_table = klass.arel_table

              if klass.version_table_backing?
                # scope.where(Arel.sql("#{assoc_table}.validity @> upper(#{klass.table_name}.validity) OR (upper_inf(#{assoc_table}.validity) AND upper_inf(#{klass.table_name}.validity))"))

                both_extant = Arel::Nodes::Grouping.new(upper_inf.call(new_table[:validity]).and(upper_inf.call(own_table[:validity])))
                assoc_existed_at_owners_upper_bound = new_table[:validity].contains(upper.call(own_table[:validity]))

                node = assoc_existed_at_owners_upper_bound.or(both_extant)

                # books_versions.validity @> upper(authors_versions.validity) OR (upper_inf(books_versions.validity) AND upper_inf(authors_versions.validity))

                def node.strata_tag
                  true
                end

                scope.where(node)
              else
                node = upper_inf.call(new_table[:validity])

                def node.strata_tag
                  true
                end

                scope.where(node)
              end
            end
          end,
          **reflection.options.merge(options)
        )
      end
    end

    def version_table_exists?(base)
      base.connection.table_exists?("#{base.table_name}_versions")
    end
  end
end
