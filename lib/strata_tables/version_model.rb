module StrataTables
  module VersionModel
    extend ActiveSupport::Concern

    included do
      reversionify
    end

    class_methods do
      def reversionify(base = nil)
        VersionModel.versionify(self, base || superclass)
      end

      def polymorphic_class_for(name)
        super.version
      end

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

    module_function

    def versionify(version_model, base)
      version_model.as_of_attribute = :sys_period
      versionfiy_table_name(version_model, base)
      versionfiy_associations(version_model, base)
      versionify_primary_key(version_model, base)
    end

    def versionfiy_table_name(version_model, base)
      if base.version_table_for
        version_model.table_name = base.version_table_for
      end
    end

    def versionify_primary_key(version_model, base)
      if base.version_table_for
        version_model.primary_key = :version_id
      end
    end

    def versionfiy_associations(version_model, base)
      base.reflect_on_all_associations.each do |reflection|
        options = if reflection.polymorphic?
          {
            primary_key: reflection.options[:primary_key] || :id
          }
        else
          {
            primary_key: reflection.klass.primary_key,
            foreign_key: reflection.foreign_key,
            class_name: reflection.klass.version.name
          }
        end

        scope = version_model.temporal_association_scope(&reflection.scope)

        version_model.send(
          reflection.macro,
          reflection.name,
          scope,
          **reflection.options.merge(options)
        )
      end
    end
  end
end
