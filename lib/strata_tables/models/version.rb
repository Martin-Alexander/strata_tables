module StrataTables
  module Models
    module Version
      extend ActiveSupport::Concern

      def strata_version_class?(klass)
        klass.respond_to?(:strata_version?) && klass.strata_version?
      end

      module_function :strata_version_class?

      included do
        if strata_backed?
          change_table_name
          add_default_scope
        end

        versionify_all_associations
      end

      class_methods do
        def strata_version?
          true
        end

        def polymorphic_class_for(name)
          super("#{name}::Version")
        end

        def sti_name
          super.chomp("::Version")
        end

        def sti_class_for(name)
          super("#{name}::Version")
        end

        private

        def strata_backed?
          connection.table_exists?(version_table_name)
        end

        def version_table_name
          "#{table_name}_versions"
        end

        def change_table_name
          self.table_name = version_table_name
        end

        def add_default_scope
          default_scope { order(validity: :desc) }
          default_scope do
            as_of_time = Thread.current[:strata_tables_as_of_time]

            if as_of_time
              where("#{table_name}.validity @> ?::timestamp", as_of_time.utc.strftime("%Y-%m-%d %H:%M:%S.%6N %z"))
            else
              all
            end
          end
        end

        def versionify_all_associations
          reflect_on_all_associations.dup.each do |reflection|
            next if reflection.polymorphic? || Version.strata_version_class?(reflection.klass)

            send(
              reflection.macro,
              reflection.name,
              reflection.scope,
              **reflection.options.merge(
                foreign_key: reflection.foreign_key,
                class_name: "#{reflection.klass.name}::Version"
              )
            )
          end
        end
      end
    end
  end
end
