module StrataTables
  module Model
    extend ActiveSupport::Concern

    class_methods do
      delegate :as_of, to: :version

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
    end

    def as_of(time)
      self.class.version.as_of(time).find_by(id: id)
    end

    def versions
      self.class.version.where(id: id)
    end
  end
end
