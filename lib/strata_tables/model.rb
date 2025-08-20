module StrataTables
  module Model
    extend ActiveSupport::Concern

    class_methods do
      def versions
        "#{name}::Version".constantize.all
      end

      def const_missing(name)
        if name.to_s == "Version"
          klass = Class.new(self) do
            include Models::Version
          end

          const_set(name, klass)
        else
          super
        end
      end
    end

    def version
      "#{self.class.name}::Version".constantize.find_by(id: id)
    end
  end
end
