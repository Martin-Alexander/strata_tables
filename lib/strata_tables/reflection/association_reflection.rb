module StrataTables
  module Reflection
    module AssociationReflection
      def check_eager_loadable!
        if active_record.include?(StrataTables::VersionModel)
          _check_eager_loadable!
        else
          super
        end
      end

      private

      def _check_eager_loadable!
        return unless scope

        req_args = scope.arity.negative? ? ~scope.arity : scope.arity

        unless req_args == 0
          raise ArgumentError, <<-MSG.squish
            The association scope '#{name}' is instance dependent (the scope
            block takes an argument). Eager loading instance dependent scopes
            is not supported.
          MSG
        end
      end
    end
  end
end
