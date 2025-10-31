module StrataTables
  module Reflection
    module AssociationReflection
      def check_eager_loadable!
        super unless as_of_scope? && scope_requires_no_params?
      end

      private

      def as_of_scope?
        scope.respond_to?(:as_of_scope?) && scope.as_of_scope?
      end

      def scope_requires_no_params?
        scope.arity == 0 || scope.arity == -1
      end
    end
  end
end
