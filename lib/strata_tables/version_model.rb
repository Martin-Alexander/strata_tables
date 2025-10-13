module StrataTables
  module VersionModel
    extend ActiveSupport::Concern

    included do
      attr_accessor :as_of_value

      reversionify
    end

    class_methods do
      delegate :as_of, to: :all

      def reversionify(base = nil)
        StrataTables::VersionModel.versionify(self, base || superclass)
      end

      def version_table_backing?
        table_name.end_with?("_versions")
      end

      def polymorphic_class_for(name)
        super.version
      end

      def sti_class_for(name)
        super.version
      end
    end

    def as_of(time)
      reload.as_of!(time)
    end

    def as_of!(time)
      self.as_of_value = time
      self
    end

    module_function

    def versionify(klass, base)
      versionfiy_table_name(klass, base)
      versionfiy_associations(klass, base)
      versionify_primary_key(klass, base)

      base.define_singleton_method(:version) do
        klass
      end
    end

    def versionfiy_table_name(klass, base)
      if version_table_exists?(base)
        klass.table_name = "#{base.table_name}_versions"
      end
    end

    def versionify_primary_key(klass, base)
      if version_table_exists?(base)
        klass.primary_key = :version_id
      end
    end

    def versionfiy_associations(klass, base)
      base.reflect_on_all_associations.each do |reflection|
        if reflection.polymorphic?
          options = {
            primary_key: reflection.options[:primary_key] || :id
          }

          klass.send(
            reflection.macro,
            reflection.name,
            ->(owner = nil) do
              as_of(owner.as_of_value)
            end,
            **reflection.options.merge(options)
          )

          next
        end

        options = {
          primary_key: reflection.klass.primary_key,
          foreign_key: reflection.foreign_key,
          class_name: reflection.klass.version.name
        }

        klass.send(
          reflection.macro,
          reflection.name,
          ->(owner = nil) do
            scope = reflection.scope ? instance_exec(owner, &reflection.scope) : all

            if !reflection.klass.version.version_table_backing?
              return scope.as_of(owner&.as_of_value)
            end

            if owner
              scope.as_of(owner.as_of_value)
            else
              node = Arel::Nodes::NamedFunction.new(
                "upper_inf",
                [reflection.klass.version.arel_table[:validity]]
              )

              node.define_singleton_method(:strata_tag) { true }

              scope.where(node)
            end
          end,
          **reflection.options.merge(options)
        )
      end
    end

    def version_table_exists?(base)
      base.connection.table_exists?("#{base.table_name}_versions")
    end
  end
end
