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

          version_model = Class.new(model) do
            include SystemVersioned
          end

          const_set(name, version_model)
        end
      end
    end
  end
end
