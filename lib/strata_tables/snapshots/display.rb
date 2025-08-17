module StrataTables
  module Snapshots
    module Display
      extend ActiveSupport::Concern

      class_methods do
        def label
          "#{name}Snapshot@#{snapshot_time.iso8601}"
        end

        def inspect
          if !schema_loaded? || !connected?
            label
          elsif table_exists?
            attr_list = attribute_types.map { |name, type| "#{name}: #{type.type}" } * ", "
            "#{label}(#{attr_list})"
          else
            "#{label}(Table doesn't exist)"
          end
        end

        def to_s
          label
        end
      end

      def label
        self.class.label
      end

      def to_s
        super.gsub(/#<Class:0x[0-9a-f]+>/, label)
      end

      def pretty_print(pp)
        pp.group(1, "#<" + label, ">") do
          if @attributes
            attr_names = attributes_for_inspect.select { |name| _has_attribute?(name.to_s) }
            pp.seplist(attr_names, proc { pp.text "," }) do |attr_name|
              attr_name = attr_name.to_s
              pp.breakable " "
              pp.group(1) do
                pp.text attr_name
                pp.text ":"
                pp.breakable
                value = attribute_for_inspect(attr_name)
                pp.text value
              end
            end
          else
            pp.breakable " "
            pp.text "not initialized"
          end
        end
      end
    end
  end
end
