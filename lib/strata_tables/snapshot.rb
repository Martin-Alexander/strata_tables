module StrataTables
  module Snapshot
    def create_snapshot_class_for(ar_model)
      # if ar_model.respond_to?(:strata_version) && ar_model.strata_version
      #   return create_snapshot_class_for(ar_model.superclass)
      # end

      # return ar_model::Snapshot if ar_model.const_defined?(:Snapshot, false)

      # snapshot_class = Class.new(ar_model) do
      #   self.table_name = "strata_#{ar_model.table_name}"
      #   self.primary_key = :id

      #   attribute :at, :datetime

      #   def self.at(time)
      #     all.at(time)
      #   end

      #   def readonly?
      #     true
      #   end

      #   reflect_on_all_associations.dup.each do |association|
      #     send(
      #       association.macro,
      #       association.name,
      #       ->(object) do
      #         at(object.at)
      #         # where("strata_#{association.klass.table_name}.validity @> ?::timestamp", object.at.utc.strftime("%Y-%m-%d %H:%M:%S.%6N %z"))
      #       end,
      #       **association.options.merge(
      #         class_name: "#{association.klass.name}::Snapshot",
      #         foreign_key: association.foreign_key
      #       )
      #     )
      #   end
      # end

      # ar_model.const_set(:Snapshot, snapshot_class)
    end
  end
end
