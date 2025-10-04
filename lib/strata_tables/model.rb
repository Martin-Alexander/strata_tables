module StrataTables
  module Model
    extend ActiveSupport::Concern

    included do |base|
      reversionify

      attr_accessor :_as_of

      scope :valid_as_of, ->(as_of) do
        return all unless table_name.end_with?("_versions")

        if as_of
          where("#{table_name}.validity @> ?::timestamptz", as_of)
        else
          where("upper(#{table_name}.validity) is null")
        end
      end
    end

    class_methods do
      def reversionify(base = nil)
        StrataTables::Model.versionify(self, base || superclass)
      end
    end

    def as_of
      _as_of || (respond_to?(:validity) && validity.end) || nil
    end

    module_function

    def versionify(klass, base)
      versionfiy_table_name(klass, base)
      versionfiy_associations(klass, base)
      versionify_primary_key(klass, base)
    end

    def versionfiy_table_name(klass, base)
      if base.connection.table_exists?("#{base.table_name}_versions")
        klass.table_name = "#{base.table_name}_versions"
      end
    end

    def versionify_primary_key(klass, base)
      if base.connection.table_exists?("#{base.table_name}_versions")
        klass.primary_key = :version_id
      end
    end

    def versionfiy_associations(klass, base)
      base.reflect_on_all_associations.each do |reflection|
        klass.send(
          reflection.macro,
          reflection.name,
          ->(owner = nil) do
            scope = reflection.scope ? instance_exec(owner, &reflection.scope) : all

            if owner
              scope.valid_as_of(owner.as_of)
            else
              scope
            end
          end,
          **reflection.options.merge(
            primary_key: reflection.klass.primary_key,
            foreign_key: reflection.foreign_key,
            class_name: "#{reflection.klass.name}::Version"
          )
        )
      end
    end
  end
end
