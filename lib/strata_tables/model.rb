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
      reload.as_of!(time) # unless respond_to?(:validity) && !validity.cover?(time)
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

    # def base_scope(reflection, owner)
    #   reflection.scope ? instance_exec(owner, &reflection.scope) : all
    # end

    # def has_many_through_scope(reflection, scope, owner)
    #   if owner&.as_of_value
    #     return scope._as_of(owner.as_of_value)
    #   end

    #   return scope
    # end
    
    # def instance_dependent_scope(klass, reflection, scope, owner)
    #   assoc_table = reflection.klass.version.table_name
    #   if owner.as_of_value
    #     scope.as_of(owner.as_of_value)
    #   elsif klass.version_table_backing?
    #     if reflection.macro == :has_many
    #       if owner.validity_end
    #         scope.where(
    #           "#{assoc_table}.validity @> ?::timestamptz", owner.validity_end
    #         )
    #       else
    #         scope.where("upper_inf(#{assoc_table}.validity)")
    #       end
    #     else
    #       if owner.validity_end
    #         scope.where(
    #           "#{assoc_table}.validity @> upper(#{klass.table_name}.validity)"
    #         )
    #       else
    #         scope.where("upper_inf(#{assoc_table}.validity)")
    #       end
    #     end
    #   else
    #     scope.where("upper_inf(#{assoc_table}.validity)")
    #   end
    # end

    # def instance_independent_scope(reflection, scope)
    # end

    def versionfiy_associations(klass, base)
      base.reflect_on_all_associations.each do |reflection|
        options = {
          primary_key: reflection.klass.primary_key,
          foreign_key: reflection.foreign_key,
          class_name: "#{reflection.klass.name}::Version"
        }

        klass.send(
          reflection.macro,
          reflection.name,
          ->(owner = nil) do
            scope = reflection.scope ? instance_exec(owner, &reflection.scope) : all

            # puts "Owner: #{owner.class}\tActive record: #{reflection.active_record.version}\tClass: #{reflection.klass.version}\tThrough: #{reflection.options[:through]}"

            # assoc_klass = reflection.klass.version

            # klass_table = klass.table_name
            # assoc_klass_table = assoc_klass.table_name

            # klass_temporal = klass.version_table_backing?
            # assoc_klass_temporal = assoc_klass.version_table_backing?

            # is_through_assoc = reflection.options.has_key?(:through)
            # is_has_many_assoc = reflection.macro == :has_many

            # if is_through_assoc
            #   if owner&.as_of_value
            #     return scope._as_of(owner.as_of_value)
            #   end

            #   return scope
            # end

            # if !assoc_klass_temporal
            #   if owner&.as_of_value
            #     return scope._as_of(owner.as_of_value)
            #   end

            #   return scope
            # end


            if !reflection.klass.version.version_table_backing?
              if owner&.as_of_value
                if reflection.options.has_key?(:through)
                  return scope._as_of(owner.as_of_value)
                else
                  return scope.as_of(owner.as_of_value)
                end
              else
                return scope
              end
            end

            assoc_table = reflection.klass.version.table_name

            if owner
              if owner.as_of_value
                if reflection.options.has_key?(:through)
                  scope._as_of(owner.as_of_value)
                else
                  scope.as_of(owner.as_of_value)
                end
              elsif klass.version_table_backing?
                if reflection.options.has_key?(:through)
                  scope
                elsif reflection.macro == :has_many
                  if owner.validity_end
                    scope.where(
                      "#{assoc_table}.validity @> ?::timestamptz",
                      owner.validity_end
                    )
                  else
                    scope.where("upper_inf(#{assoc_table}.validity)")
                  end
                else
                  if owner.validity_end
                    scope.where(
                      "#{assoc_table}.validity @> upper(#{klass.table_name}.validity)"
                    )
                  else
                    scope.where("upper_inf(#{assoc_table}.validity)")
                  end
                end
              else
                scope.where("upper_inf(#{assoc_table}.validity)")
              end
            else
              return scope if reflection.options.has_key?(:through)

              upper = ->(arg) do
                Arel::Nodes::NamedFunction.new("upper", [arg])
              end

              upper_inf = ->(arg) do
                Arel::Nodes::NamedFunction.new("upper_inf", [arg])
              end

              new_table = reflection.klass.version.arel_table
              own_table = klass.arel_table

              if klass.version_table_backing?
                both_extant = Arel::Nodes::Grouping.new(
                  upper_inf.call(new_table[:validity])
                    .and(upper_inf.call(own_table[:validity]))
                )
                assoc_existed_at_owners_upper_bound = new_table[:validity]
                  .contains(upper.call(own_table[:validity]))

                node = assoc_existed_at_owners_upper_bound.or(both_extant)

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
