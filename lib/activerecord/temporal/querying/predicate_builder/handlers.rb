module ActiveRecord::Temporal::Querying
  class PredicateBuilder
    require_relative "contains_handler"

    module Handlers
      Contains = Struct.new(:time)

      extend ActiveSupport::Concern

      class_methods do
        def contains(time)
          Contains.new(time)
        end

        def predicate_builder
          super.tap do |base_predicate_builder|
            register_predicate_builder_handlers(base_predicate_builder)
          end
        end

        private

        def register_predicate_builder_handlers(base_predicate_builder)
          @register_predicate_builder_handlers ||= base_predicate_builder
            .register_handler Contains,
              PredicateBuilder::ContainsHandler.new(base_predicate_builder)
        end
      end
    end
  end
end
