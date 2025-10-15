module StrataTables
  module Model
    extend ActiveSupport::Concern

    class_methods do
      delegate :as_of, to: :version

      def version
        "#{name}::Version".constantize
      end

      def versions
        version.all
      end

      def const_missing(name)
        if name.to_s == "Version"
          klass = Class.new(self)

          const_set(name, klass)

          klass.include(StrataTables::VersionModel)
        else
          super
        end
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
