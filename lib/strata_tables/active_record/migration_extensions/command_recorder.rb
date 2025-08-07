module StrataTables
  module ActiveRecord
    module CommandRecorder
      {
        create_strata_triggers: :drop_strata_triggers,
        add_column_to_strata_triggers: :remove_column_from_strata_triggers,
      }.each do |method, inverse|
        [[method, inverse], [inverse, method]].each do |method, inverse|
          class_eval <<-EOV, __FILE__, __LINE__ + 1
            def invert_#{method}(args)
              [:#{inverse}, args]
            end
          EOV

          class_eval <<-EOV, __FILE__, __LINE__ + 1
            def #{method}(*args)
              record(:#{method}, args)
            end
          EOV

          ruby2_keywords(method)
        end
      end
    end
  end
end
