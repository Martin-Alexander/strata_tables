module StrataTables
  class SnapshotBuilder
    def self.build(ar_class, time)
      _build(ar_class, time, {})
    end

    private_class_method

    def self._build(ar_class, time, klass_repo = {})
      klass = Class.new(ar_class) do
        self.table_name = "strata_#{ar_class.table_name}"

        @time = time

        default_scope do
          time_constraint
        end

        def self.time_constraint
          where("#{table_name}.validity @> ?::timestamp", @time.utc.strftime("%Y-%m-%d %H:%M:%S.%6N %z"))
        end

        def self.label
          "#{superclass.name}Snapshot@#{@time.iso8601}"
        end

        def self.inspect
          if !schema_loaded? || !connected?
            label
          elsif table_exists?
            attr_list = attribute_types.map { |name, type| "#{name}: #{type.type}" } * ", "
            "#{label}(#{attr_list})"
          else
            "#{label}(Table doesn't exist)"
          end
        end

        def self.to_s
          label
        end

        def readonly?
          true
        end

        def label
          self.class.label
        end

        def to_s
          super.gsub(/#<Class:0x[0-9a-f]+>/, self.class.label)
        end

        def pretty_print(pp)
          pp.group(1, "#<" + self.class.label, ">") do
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

      klass_repo[ar_class.name] = klass

      klass.reflect_on_all_associations.dup.each do |association|
        assoc_klass = klass_repo[association.klass.name] || _build(association.klass, time, klass_repo)

        args = [
          klass,
          association.name,
          association.scope,
          association.options.merge(klass: assoc_klass, foreign_key: association.foreign_key)
        ]

        reflection_builder = case association.macro
        when :has_many
          StrataTables::Associations::Builder::HasMany
        when :has_one
          StrataTables::Associations::Builder::HasOne
        when :belongs_to
          StrataTables::Associations::Builder::BelongsTo
        else
          raise "Unsupported Macro: #{association.macro}"
        end

        reflection = reflection_builder.build(*args)

        ActiveRecord::Reflection.add_reflection(klass, association.name, reflection)
      end

      klass
    end
  end
end
