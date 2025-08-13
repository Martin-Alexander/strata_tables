module StrataTables
  class Snapshotter
    def snapshot_at(time)
      yield
    end
  end
end
