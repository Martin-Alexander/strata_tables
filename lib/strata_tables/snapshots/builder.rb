module StrataTables
  module Snapshots
    class Builder
      def self.build(ar_class, time, snapshot_klass_repo = {})
        klass = Class.new(ar_class) do
          class_attribute :snapshot_time, instance_writer: false
          class_attribute :snapshot_klass_repo, instance_writer: false
        end

        snapshot_klass_repo[ar_class.name] = klass

        klass.snapshot_time = time
        klass.snapshot_klass_repo = snapshot_klass_repo

        klass.include Snapshot

        klass
      end
    end
  end
end
