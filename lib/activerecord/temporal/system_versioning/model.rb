module ActiveRecord::Temporal
  module SystemVersioning
    module Model
      extend ActiveSupport::Concern

      included do
        include AsOfQuery

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
  end
end
