module ActiveRecord::Temporal
  module AsOfQuery
    module TimeDimensions
      extend ActiveSupport::Concern

      included do
        delegate :time_dimensions, :default_time_dimension, :time_dimension_column?, to: :class
      end

      class_methods do
        def set_time_dimensions(*dimensions)
          define_singleton_method(:time_dimensions) { dimensions }
          define_singleton_method(:default_time_dimension) { dimensions.first }
        end

        def time_dimensions = []
        def default_time_dimension = nil

        def time_dimension_column?(time_dimension)
          connection.column_exists?(table_name, time_dimension)
        end
      end

      def time_dimension(dimension = nil)
        dimension ||= default_time_dimension

        if !time_dimension_column?(dimension)
          raise ArgumentError, "no time dimension column '#{dimension}'"
        end

        send(dimension)
      end

      def time_dimension_start(dimension = nil)
        time_dimension(dimension)&.begin
      end

      def time_dimension_end(dimension = nil)
        time_dimension(dimension)&.end
      end

      def set_time_dimension(value, dimension = nil)
        dimension ||= default_time_dimension

        if !time_dimension_column?(dimension)
          raise ArgumentError, "no time dimension column '#{dimension}'"
        end

        send("#{dimension}=", value)
      end

      def set_time_dimension_start(value, dimension = nil)
        existing_value = time_dimension(dimension)

        new_value = existing_value ? value...existing_value.end : value...nil

        set_time_dimension(new_value, dimension)
      end

      def set_time_dimension_end(value, dimension = nil)
        existing_value = time_dimension(dimension)

        new_value = existing_value ? existing_value.begin...value : nil...value

        set_time_dimension(new_value, dimension)
      end
    end
  end
end
