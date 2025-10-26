module StrataTables
  module Relation
    def as_of_timestamp(timestamp)
      spawn.as_of_timestamp!(timestamp)
    end

    def as_of_timestamp!(timestamp)
      self.as_of_timestamp_values = as_of_timestamp_values.merge(timestamp)
      self
    end

    def as_of_timestamp_values
      @values.fetch(:as_of_timestamp, ActiveRecord::QueryMethods::FROZEN_EMPTY_HASH)
    end

    def as_of_timestamp_values=(timestamp)
      # TODO: add tests for: assert_modifiable!
      @values[:as_of_timestamp] = timestamp
    end

    private

    if ActiveRecord.version > Gem::Version.new("8.0.3")
      def build_arel(connection)
        ensure_as_of_timestamp_registry { super }
      end
    else
      def build_arel(connection, aliases = nil)
        ensure_as_of_timestamp_registry { super }
      end
    end

    def ensure_as_of_timestamp_registry
      set_as_of_registry_values = AsOfRegistry.timestamps.empty? && as_of_timestamp_values.any?

      return yield unless set_as_of_registry_values

      begin
        as_of_timestamp_values.each do |attribute, value|
          AsOfRegistry.timestamps[attribute] = value
        end

        yield
      ensure
        AsOfRegistry.clear
      end
    end

    def instantiate_records(rows, &block)
      super.tap do |records|
        records.each do |record|
          initialize_as_of_timestamps(record)

          walk_associations(record, includes_values | eager_load_values) do |record, assoc_name|
            reflection = record.class.reflect_on_association(assoc_name)
            next unless reflection

            assoc = record.association(assoc_name)
            target = assoc.target

            if target.is_a?(Array)
              target.each do |t|
                initialize_as_of_timestamps(t)
              end
            else
              initialize_as_of_timestamps(target)
            end
          end
        end
      end
    end

    def walk_associations(record, node, &block)
      case node
      when Symbol, String
        block.call(record, node)
      when Array
        node.each { |child| walk_associations(record, child, &block) }
      when Hash
        # TODO: Write tests

        node.each do |parent, child|
          block.call(record, parent)

          walk_associations(record, child, &block)
        end
      end
    end

    def initialize_as_of_timestamps(record)
      as_of_timestamp_values.each do |attribute, value|
        method_name = "#{attribute}_as_of="

        record.send(method_name, value) if record.respond_to?(method_name)
      end
    end
  end
end
