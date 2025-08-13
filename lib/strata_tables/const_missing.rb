module StrataTables
  module ConstMissing
    def const_missing(const_name)
      if const_name == :Snapshot && self < ::ActiveRecord::Base
        return create_snapshot_class_for(self)
      end

      super
    end
  end
end
