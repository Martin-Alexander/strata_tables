module StrataTables
  module ApplicationVersioning
    class Revision
      attr_reader :record, :time, :options

      def initialize(record, time, **options)
        @record = record
        @time = time
        @options = options
      end

      def with(attributes)
        new_revision = record.dup
        new_revision.assign_attributes(attributes)
        new_revision.period_start = time
        new_revision.as_of_value = record.as_of_value
        record.period_end = time

        new_revision.initialize_revsion(record)

        if options[:save]
          record.class.transaction do
            new_revision.save if record.save
          end
        end

        [new_revision, record]
      end
    end

    def revise
      revise_at(Time.current)
    end

    def revise_at(time)
      raise "not head revision" unless head_revision?

      Revision.new(self, time, save: true)
    end
  end
end
