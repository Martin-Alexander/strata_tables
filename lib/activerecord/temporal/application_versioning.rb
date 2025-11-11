module ActiveRecord::Temporal
  module ApplicationVersioning
    extend ActiveSupport::Concern

    included do
      include AsOfQuery
    end

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
        new_revision.set_time_dimension_start(time)
        new_revision.time_scopes = record.time_scopes
        record.set_time_dimension_end(time)

        new_revision.after_initialize_revision(record)

        if options[:save]
          record.class.transaction do
            new_revision.save if record.save
          end
        end

        [new_revision, record]
      end
    end

    def after_initialize_revision(old_revision)
      self.version = old_revision.version + 1
      self.id_value = old_revision.id_value
    end

    def head_revision?
      time_dimension && !time_dimension_end
    end

    def revise
      revise_at(Time.current)
    end

    def revise_at(time)
      raise "not head revision" unless head_revision?

      Revision.new(self, time, save: true)
    end

    def revision
      revision_at(Time.current)
    end

    def revision_at(time)
      raise "not head revision" unless head_revision?

      Revision.new(self, time, save: false)
    end

    def inactivate
      inactivate_at(Time.current)
    end

    def inactivate_at(time)
      raise "not head revision" unless head_revision?

      set_time_dimension_end(time)
      save
    end
  end
end
