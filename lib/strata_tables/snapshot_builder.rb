module StrataTables
  class SnapshotBuilder
    def self.build(ar_class, time)
      _build(ar_class, time, {})
    end

    private_class_method

    def self._build(ar_class, time, snapshot_klass_repo = {})
      klass = Class.new(ar_class) do
        if ActiveRecord::Base.connection.table_exists?("strata_#{ar_class.table_name}")
          self.table_name = "strata_#{ar_class.table_name}"

          default_scope do
            time_constraint
          end

          def self.time_constraint
            where("#{table_name}.validity @> ?::timestamp", @time.utc.strftime("%Y-%m-%d %H:%M:%S.%6N %z"))
          end
        end

        @time = time

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

      snapshot_klass_repo[ar_class.name] = klass

      klass.reflect_on_all_associations.dup.each do |reflection|
        next if reflection.polymorphic? || !ActiveRecord::Base.connection.table_exists?("strata_#{reflection.klass.table_name}")

        snapshot_klass = snapshot_klass_repo[reflection.klass.name] ||
          _build(reflection.klass, time, snapshot_klass_repo)

        klass.send(
          reflection.macro,
          reflection.name,
          reflection.scope,
          **reflection.options.merge(foreign_key: reflection.foreign_key)
        )

        new_reflection = klass.reflect_on_association(reflection.name)

        new_reflection.define_singleton_method(:klass) do
          snapshot_klass
        end
      end

      klass.define_singleton_method(:polymorphic_class_for) do |name|
        # TODO: what is this conditional?
        if store_full_class_name
          snapshot_klass_repo[name] || SnapshotBuilder._build(super(name), time, snapshot_klass_repo)
        else
          compute_type(name)
        end
      end

      klass
    end
  end
end
