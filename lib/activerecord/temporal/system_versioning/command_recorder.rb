module ActiveRecord::Temporal
  module SystemVersioning
    module CommandRecorder
      module ArrayExtractOptions
        refine Array do
          def extract_options
            if last.is_a?(Hash) && last.extractable_options?
              last
            else
              {}
            end
          end
        end
      end

      using ArrayExtractOptions

      [
        :create_versioning_hook,
        :drop_versioning_hook,
        :change_versioning_hook,
        :create_table_with_system_versioning,
        :drop_table_with_system_versioning
      ].each do |method|
        class_eval <<-EOV, __FILE__, __LINE__ + 1
          def #{method}(*args)
            record(:#{method}, args)
          end
        EOV

        ruby2_keywords(method)
      end

      def invert_drop_versioning_hook(args)
        _, _, columns = args

        if columns.nil?
          raise ActiveRecord::IrreversibleMigration, "drop_versioning_hook is only reversible if given :columns option."
        end

        [:create_versioning_hook, args]
      end

      def invert_create_versioning_hook(args)
        [:drop_versioning_hook, args]
      end

      def invert_change_versioning_hook(args)
        source_table, history_table, options = args

        [
          :change_versioning_hook,
          [
            source_table,
            history_table,
            add_columns: options[:remove_columns],
            remove_columns: options[:add_columns]
          ]
        ]
      end

      def invert_create_table_with_system_versioning(args)
        [:drop_table_with_system_versioning, args]
      end

      def invert_drop_table_with_system_versioning(args)
        # TODO make this reversible

        raise ActiveRecord::IrreversibleMigration, "drop_table_with_system_versioning is not reversible"
      end
    end
  end
end
