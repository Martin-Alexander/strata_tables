module ActiveRecord::Temporal
  module Patches
    module AssociationReflection
      def check_eager_loadable!
        super unless temporal_scope? && scope_requires_no_params?
      end

      private

      def temporal_scope?
        scope.respond_to?(:temporal_scope?) && scope.temporal_scope?
      end

      def scope_requires_no_params?
        scope.arity == 0 || scope.arity == -1
      end
    end
  end
end
