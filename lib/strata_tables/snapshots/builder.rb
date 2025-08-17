module StrataTables
  module Snapshots
    class Builder
      class << self
        def build(object, time, snapshot_klass_repo = {})
          if object.is_a?(Class) && object < ActiveRecord::Base
            build_snapshot_class(object, time, snapshot_klass_repo)
          elsif object.is_a?(ActiveRecord::Relation)
            build_snapshot_relation(object, time, snapshot_klass_repo)
          else
            build_snapshot_instance(object, time, snapshot_klass_repo)
          end
        end

        private

        def build_snapshot_class(ar_class, time, snapshot_klass_repo)
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

        def build_snapshot_instance(ar_instance, time, snapshot_klass_repo)
          klass = build_snapshot_class(ar_instance.class, time, snapshot_klass_repo)
          klass.find(ar_instance.id)
        end

        def build_snapshot_relation(ar_relation, time, snapshot_klass_repo)
          # TODO: handle eager loading and preloading

          klass = build_snapshot_class(ar_relation.klass, time, snapshot_klass_repo)
          klass.where(id: ar_relation.pluck(:id))
        end
      end
    end
  end
end
