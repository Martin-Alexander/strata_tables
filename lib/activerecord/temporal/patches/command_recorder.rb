module ActiveRecord::Temporal
  module Patches
    module CommandRecorder
      def invert_drop_table(args, &block)
        if extract_options(args).delete(:system_versioning)
          raise ActiveRecord::IrreversibleMigration, "drop_table with system versioning is not supported"
        end

        super
      end

      private

      def extract_options(array)
        if array.last.is_a?(Hash) && array.last.extractable_options?
          array.last
        else
          {}
        end
      end
    end
  end
end
