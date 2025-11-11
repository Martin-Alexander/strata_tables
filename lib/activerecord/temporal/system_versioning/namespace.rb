module ActiveRecord::Temporal
  module SystemVersioning
    module Namespace
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

              include Model
            end
          else
            Class.new(model) do
              include Model
            end
          end

          const_set(name, version_model)
        end
      end
    end
  end
end
