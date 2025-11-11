module ActiveRecord::Temporal
  module AsOfQuery
    module AssociationMacros
      extend ActiveSupport::Concern

      class_methods do
        def has_many(name, scope = nil, **options, &extension)
          scope = handle_temporal_scope_option(scope, options)

          super
        end

        def has_one(name, scope = nil, **options)
          scope = handle_temporal_scope_option(scope, options)

          super
        end

        def belongs_to(name, scope = nil, **options)
          scope = handle_temporal_scope_option(scope, options)

          super
        end

        def has_and_belongs_to_many(name, scope = nil, **options, &extension)
          scope = handle_temporal_scope_option(scope, options)

          super
        end

        private

        def handle_temporal_scope_option(scope, options)
          temporal = options.extract!(:temporal)[:temporal]

          temporal ? AssociationScope.build(scope) : scope
        end
      end
    end
  end
end
