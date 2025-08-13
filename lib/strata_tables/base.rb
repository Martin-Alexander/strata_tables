module StrataTables
  module Base
    def self.included(base)
      base.include StrataTables::ConstMissing
      base.include StrataTables::Snapshot
    end
  end
end
