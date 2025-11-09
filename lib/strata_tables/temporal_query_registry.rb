module StrataTables
  class TemporalQueryRegistry
    class << self
      delegate :default_scopes, :query_scopes, :set_default_scopes, :query_scope_for, :with_query_scope, to: :instance

      def instance
        ActiveSupport::IsolatedExecutionState[:strata_tables_registry] ||= new
      end
    end

    attr_reader :default_scopes, :query_scopes

    def initialize
      @default_scopes = {}
      @query_scopes = {}
    end

    def set_default_scopes(default_scopes)
      @default_scopes = default_scopes
    end

    def query_scope_for(dimensions)
      query_scopes.slice(*dimensions)
    end

    def with_query_scope(scope, &block)
      original = @query_scopes.dup

      @query_scopes = @query_scopes.merge(scope)

      block.call
    ensure
      @query_scopes = original
    end
  end
end
