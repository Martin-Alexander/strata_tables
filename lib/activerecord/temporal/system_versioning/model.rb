module ActiveRecord::Temporal
  module SystemVersioning
    module Model
      extend ActiveSupport::Concern

      included do
        include AsOfQuery

        self.time_dimensions = time_dimensions + [:system_period]

        if history_table
          self.table_name = history_table
          self.primary_key = Array(primary_key) + [:system_period]
        end

        reflect_on_all_associations.each do |reflection|
          next if reflection.scope&.temporal_scope?

          send(
            reflection.macro,
            reflection.name,
            reflection.scope,
            **reflection.options.merge(temporal: true)
          )
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
  end
end
