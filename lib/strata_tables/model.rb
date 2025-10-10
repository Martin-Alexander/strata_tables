module StrataTables
  module Model
    extend ActiveSupport::Concern

    class_methods do
      def version
        "#{name}::Version".constantize
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
  end
end
