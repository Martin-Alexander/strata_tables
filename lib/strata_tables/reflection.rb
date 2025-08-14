module StrataTables
  module Reflection
    class << self
      def create(macro, name, scope, options, ar)
        # reflection = reflection_class_for(macro).new(name, scope, options, ar)
        # options[:through] ? ThroughReflection.new(reflection) : reflection

        reflection_class_for(macro).new(name, scope, options, ar)
      end

      private

      def reflection_class_for(macro)
        case macro
        when :has_many
          StrataTables::Reflection::HasManyReflection
        when :belongs_to
          StrataTables::Reflection::BelongsToReflection
        else
          raise "Unsupported Macro: #{macro}"
        end
      end
    end

    class BelongsToReflection < ActiveRecord::Reflection::BelongsToReflection
      def klass
        options[:klass]
      end
    end

    class HasManyReflection < ActiveRecord::Reflection::HasManyReflection
      def klass
        options[:klass]
      end
    end
  end
end
