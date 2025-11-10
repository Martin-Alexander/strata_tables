module ActiveRecordTemporalTests
  module RecordFactory
    extend ActiveSupport::Concern

    class_methods do
      def build_records(&block)
        block.call.each do |model_name, records|
          records.each do |method_name, attrs|
            let!(method_name) do
              model = model_name.constantize

              create_attrs = if model.primary_key.is_a?(Array)
                attrs.except(:id).merge(id_value: attrs[:id])
              else
                attrs
              end

              record = model.find_by(attrs)

              if !record
                model.create!(create_attrs)
              else
                record
              end
            end
          end
        end
      end
    end
  end
end
