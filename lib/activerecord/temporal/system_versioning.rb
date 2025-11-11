module ActiveRecord::Temporal
  module VersionModel
    extend ActiveSupport::Concern

    included do
      include AsOf

      set_time_dimensions :system_period

      reflect_on_all_associations.each do |reflection|
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
      rescue NameError
        super
      else
        unless model.is_a?(Class) && model < ActiveRecord::Base
          raise NameError, "#{model} is not a descendent of ActiveRecord::Base"
        end

        version_model = if (history_table = model.history_table)
          Class.new(model) do
            self.table_name = history_table
            self.primary_key = model.primary_key_from_db + [:system_period]

            include VersionModel
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

    class_methods do
      def history_table
        connection.history_table(table_name)
      end

      def primary_key_from_db
        Array(connection.primary_key(table_name)).map(&:to_sym)
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
