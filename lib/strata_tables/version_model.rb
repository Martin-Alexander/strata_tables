module StrataTables
  module VersionModel
    extend ActiveSupport::Concern

    included do
      extend AsOfConstraints

      attr_accessor :sys_period_as_of

      reversionify

      scope :as_of, ->(time) do
        existed_at(time).as_of_timestamp(sys_period: time)
      end

      scope :existed_at, ->(time) do
        return unless history_table?

        where(existed_at_constraint(time, :sys_period))
      end

      scope :extant, -> do
        return unless history_table?

        where(extant_constraint(:sys_period))
      end
    end

    class_methods do
      delegate :as_of, to: :all

      def reversionify(base = nil)
        StrataTables::VersionModel.versionify(self, base || superclass)
      end

      def history_table?
        @history_table ||= connection.history_table?(table_name)
      end

      def polymorphic_class_for(name)
        super.version
      end

      def sti_name
        superclass.sti_name
      end

      def find_sti_class(type_name)
        superclass.send(:find_sti_class, type_name).version
      end

      def finder_needs_type_condition?
        superclass.finder_needs_type_condition?
      end
    end

    def as_of(time)
      reload.as_of!(time)
    end

    def as_of!(time)
      self.sys_period_as_of = time
      self
    end

    module_function

    def versionify(version_model, base)
      versionfiy_table_name(version_model, base)
      versionfiy_associations(version_model, base)
      versionify_primary_key(version_model, base)
    end

    def versionfiy_table_name(version_model, base)
      if base.version_table_for
        version_model.table_name = base.version_table_for
      end
    end

    def versionify_primary_key(version_model, base)
      if base.version_table_for
        version_model.primary_key = :version_id
      end
    end

    def versionfiy_associations(version_model, base)
      base.reflect_on_all_associations.each do |reflection|
        if reflection.polymorphic?
          version_model.send(
            reflection.macro,
            reflection.name,
            ->(owner = nil) do
              owner.sys_period_as_of ? as_of(owner.sys_period_as_of) : extant
            end,
            **reflection.options.merge(
              primary_key: reflection.options[:primary_key] || :id
            )
          )
        else
          reflection.klass.version

          version_model.send(
            reflection.macro,
            reflection.name,
            ->(owner = nil) do
              scope = reflection.scope ? instance_exec(owner, &reflection.scope) : all

              as_of_time = owner&.sys_period_as_of
              as_of_time ||= AsOfRegistry.timestamps[:sys_period]

              as_of_time ? scope.as_of(as_of_time) : scope.extant
            end,
            **reflection.options.merge(
              primary_key: reflection.klass.primary_key,
              foreign_key: reflection.foreign_key,
              class_name: reflection.klass.version.name
            )
          )
        end
      end
    end
  end
end
