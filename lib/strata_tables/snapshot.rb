module StrataTables
  module Snapshot
    extend ActiveSupport::Concern

    included do
      include Snapshots::Display

      if backed_by_strata_table?(self)
        self.table_name = "strata_#{superclass.table_name}"

        default_scope { validity_constraint }
      end

      reflect_on_all_associations.dup.each do |reflection|
        next if reflection.polymorphic?

        snapshot_klass = find_or_build_snapshot(reflection.klass)

        send(
          reflection.macro,
          reflection.name,
          reflection.scope,
          **reflection.options.merge(
            foreign_key: reflection.foreign_key,
            anonymous_class: snapshot_klass
          )
        )
      end
    end

    class_methods do
      def backed_by_strata_table?(klass)
        connection.table_exists?("strata_#{klass.table_name}")
      end

      def validity_constraint
        where("#{table_name}.validity @> ?::timestamp", snapshot_time.utc.strftime("%Y-%m-%d %H:%M:%S.%6N %z"))
      end

      def name
        superclass.name
      end

      def polymorphic_class_for(name)
        find_or_build_snapshot(super)
      end

      def sti_class_for(name)
        find_or_build_snapshot(super)
      end

      private

      def find_or_build_snapshot(klass)
        snapshot_klass_repo[klass.name] ||
          Snapshots::Builder.build(klass, snapshot_time, snapshot_klass_repo)
      end
    end

    def readonly?
      true
    end
  end
end
