module StrataTables
  class AsOfRegistry
    class << self
      delegate :[], :[]=, :clear, :timestamps, to: :instance

      def instance
        ActiveSupport::IsolatedExecutionState[:strata_tables_as_of_registry] ||= new
      end
    end

    delegate :[], :[]=, to: :timestamps

    attr_reader :timestamps

    def initialize
      @timestamps = {}.with_indifferent_access
    end

    def clear
      @timestamps = {}.with_indifferent_access
    end
  end
end
