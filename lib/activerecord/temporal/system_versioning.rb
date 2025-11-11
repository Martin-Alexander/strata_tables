module ActiveRecord::Temporal
  module SystemVersioning
    extend ActiveSupport::Concern

    class_methods do
      def history_table
        connection.history_table(table_name)
      end

      def primary_key_from_db
        Array(connection.primary_key(table_name)).map(&:to_sym)
      end

      def version_model
        "Version::#{name}".constantize
      end

      def system_versioning(namespace: "Version")
        unless Object.const_defined?(namespace)
          mod = Module.new
          mod.include(Namespace)
          Object.const_set(namespace, mod)
        end
      end
    end
  end
end
