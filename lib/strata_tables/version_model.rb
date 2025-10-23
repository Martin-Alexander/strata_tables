module StrataTables
  module VersionModel
    extend ActiveSupport::Concern

    included do
      attr_accessor :as_of_value

      reversionify
    end

    class_methods do
      delegate :as_of, to: :all

      def reversionify(base = nil)
        StrataTables::VersionModel.versionify(self, base || superclass)
      end

      def history_table?
        table_name.end_with?("_history")
      end

      def polymorphic_class_for(name)
        super.version
      end

      # def sti_class_for(name)
      #   super.version
      # end

      def sti_name
        superclass.sti_name
      end

      def find_sti_class(type_name)
        superclass.send(:find_sti_class, type_name).version
      end

      def finder_needs_type_condition?
        superclass.finder_needs_type_condition?
      end
    end

    def as_of(time)
      reload.as_of!(time)
    end

    def as_of!(time)
      self.as_of_value = time
      self
    end

    module_function

    def versionify(version_model, base)
      versionfiy_table_name(version_model, base)
      versionfiy_associations(version_model, base)
      versionify_primary_key(version_model, base)
    end

    def versionfiy_table_name(version_model, base)
      if version_table_exists?(base)
        version_model.table_name = "#{base.table_name}_history"
      end
    end

    def versionify_primary_key(version_model, base)
      if version_table_exists?(base)
        version_model.primary_key = :version_id
      end
    end

    def versionfiy_associations(version_model, base)
      base.reflect_on_all_associations.each do |reflection|
        if reflection.polymorphic?
          version_model.send(
            reflection.macro,
            reflection.name,
            ->(owner = nil) { as_of(owner.as_of_value) },
            **reflection.options.merge(
              primary_key: reflection.options[:primary_key] || :id
            )
          )
        else
          target_model_version = reflection.klass.version

          version_model.send(
            reflection.macro,
            reflection.name,
            ->(owner = nil) do
              scope = reflection.scope ? instance_exec(owner, &reflection.scope) : all

              if !target_model_version.history_table?
                return scope.as_of(owner&.as_of_value)
              end

              if owner
                scope.as_of(owner.as_of_value)
              else
                node = ArelNodes::Extant.new(target_model_version.arel_table[:sys_period])

                scope.where(node)
              end
            end,
            **reflection.options.merge(
              primary_key: reflection.klass.primary_key,
              foreign_key: reflection.foreign_key,
              class_name: reflection.klass.version.name
            )
          )
        end
      end
    end

    def version_table_exists?(base)
      base.connection.table_exists?("#{base.table_name}_history")
    end
  end
end
