module StrataTables
  module VersionModel
    extend ActiveSupport::Concern

    include AsOf

    included do |base|
      self.as_of_attribute = :system_period

      base.reflect_on_all_associations.each do |reflection|
        scope = temporal_association_scope(&reflection.scope)

        send(reflection.macro, reflection.name, scope, **reflection.options)
      end
    end

    class_methods do
      def polymorphic_class_for(name)
        super.version_model
      end

      def sti_name
        superclass.sti_name
      end

      def find_sti_class(type_name)
        superclass.send(:find_sti_class, type_name).version_model
      end

      def finder_needs_type_condition?
        superclass.finder_needs_type_condition?
      end
    end
  end

  module SystemVersioningNamespace
    extend ActiveSupport::Concern

    class_methods do
      def const_missing(name)
        model = name.to_s.constantize

        version_model = if model.history_table
          Class.new(model) do
            include VersionModel

            self.table_name = "#{model.table_name}_history"
            self.primary_key = [:id, :system_start]
          end
        else
          Class.new(model) do
            include VersionModel
          end
        end

        const_set(name, version_model)
      end
    end
  end

  module SystemVersioning
    extend ActiveSupport::Concern

    include StrataTables::AsOf

    class_methods do
      def history_table
        connection.history_table_for(table_name)
      end

      def version_model
        "Version::#{name}".constantize
      end

      def system_versioning(namespace: "Version")
        unless Object.const_defined?(namespace)
          mod = Module.new
          mod.include(SystemVersioningNamespace)
          Object.const_set(namespace, mod)
        end
      end
    end
  end
end
