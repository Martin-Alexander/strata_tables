module StrataTables
  module Migration
    module CommandRecorder
      {
        create_history_table: :drop_history_table
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
