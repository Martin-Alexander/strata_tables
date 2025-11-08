module StrataTables
  module AsOf
    class RangeError < StandardError; end

    extend ActiveSupport::Concern

    class_methods do
      attr_accessor :default_temporal_query, :temporal_queries, :temporal_query_columns

      def temporal_query_column_exists?(temporal_query = nil)
        temporal_query ||= default_temporal_query

        temporal_query_columns[temporal_query] ||= connection.column_exists?(table_name, temporal_query)

        connection.column_exists?(table_name, temporal_query)
      end

      def existed_at_constraint(table, time, temporal_query = nil)
        temporal_query ||= default_temporal_query

        time_f = time.utc.strftime("%Y-%m-%d %H:%M:%S.%6N")

        <<~SQL
          "#{table.name}"."#{temporal_query}" @> '#{time_f}'::timestamptz
        SQL
      end

      def temporal_association_scope(&block)
        scope = build_temporal_scope(&block)

        def scope.as_of_scope? = true

        scope
      end

      def build_temporal_scope(&block)
        temporalize = ->(owner = nil, base_scope) do
          (temporal_queries | [default_temporal_query]).map do |temporal_query|
            time = owner&.temporal_query_tags&.dig(temporal_query) ||
              AsOfRegistry.timestamps[temporal_query]

            base_scope = if time
              base_scope.as_of(temporal_query => time)
            else
              base_scope.existed_at(temporal_query => Time.current)
            end
          end

          base_scope
        end

        if !block
          return ->(owner = nil) { temporalize.call(owner, all) }
        end

        if block.arity != 0
          return ->(owner) { temporalize.call(owner, instance_exec(owner, &block)) }
        end

        ->(owner = nil) { temporalize.call(owner, instance_exec(owner, &block)) }
      end
    end

    included do
      self.temporal_query_columns = {}
      self.temporal_queries = []

      scope :as_of, ->(*time, **temporal_queries) do
        time = time.first

        if time
          return existed_at(time).as_of_timestamp(default_temporal_query => time)
        end

        existed_at(**temporal_queries).as_of_timestamp(temporal_queries)
      end

      scope :existed_at, ->(*time, **temporal_queries) do
        time = time.first

        if time
          return unless temporal_query_column_exists?
          return where(existed_at_constraint(table, time))
        end

        rel = all

        temporal_queries.each do |temporal_query, time|
          next unless temporal_query_column_exists?(temporal_query)
          rel = rel.where(existed_at_constraint(table, time, temporal_query))
        end

        rel
      end
    end

    def temporal_query_tags
      @temporal_query_tags
    end

    def temporal_query_tags=(value)
      @temporal_query_tags = value
    end

    def temporal_query_tag
      temporal_query_tags&.dig(default_temporal_query)
    end

    def temporal_query_tag=(value)
      self.temporal_query_tags = {default_temporal_query => value}
    end

    def temporal_query_columns
      self.class.temporal_query_columns
    end

    def default_temporal_query
      self.class.default_temporal_query
    end

    def as_of!(*time, **temporal_queries)
      time = time.first

      reload

      if time
        if self.class.temporal_query_column_exists? && !time_range.cover?(time)
          raise RangeError, "#{time} is outside of '#{default_temporal_query}' range"
        end

        self.temporal_query_tags = {default_temporal_query => time}
      else
        self.temporal_query_tags = {}

        temporal_queries.each do |temporal_query, time|
          if self.class.temporal_query_column_exists?(temporal_query) && !time_range(temporal_query).cover?(time)
            raise RangeError, "#{time} is outside of '#{temporal_query}' range"
          end

          temporal_query_tags.merge!(default_temporal_query => time)
        end
      end
    end

    def as_of(*time, **temporal_queries)
      time = time.first

      if time
        self.class.as_of(time).find_by(self.class.primary_key => [id])
      else
        self.class.as_of(**temporal_queries).find_by(self.class.primary_key => [id])
      end
    end

    def time_range(temporal_query = nil)
      send(temporal_query || default_temporal_query)
    end
  end
end
