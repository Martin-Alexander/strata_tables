module StrataTables
  module Model
    extend ActiveSupport::Concern
    include AsOf

    included do
      self.as_of_attribute = :sys_period
    end

    class_methods do
      def version
        if const_defined?("Version", false)
          const_get("Version")
        else
          klass = Class.new(self)

          const_set(:Version, klass)

          klass.include(StrataTables::VersionModel)

          klass
        end
      end

      def versions
        version.all
      end

      def version_table_for
        @history_table_for ||= connection.history_table_for(table_name)
      end
    end

    def as_of(time)
      self.class.version.as_of(time).find_by(id: id)
    end

    def versions
      self.class.version.where(id: id)
    end
  end
end
