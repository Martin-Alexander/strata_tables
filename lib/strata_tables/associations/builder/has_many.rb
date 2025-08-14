module StrataTables
  module Associations
    module Builder
      class HasMany < ActiveRecord::Associations::Builder::HasMany
        def self.create_reflection(model, name, scope, options, &block)
          raise ArgumentError, "association names must be a Symbol" unless name.kind_of?(Symbol)

          validate_options(options)

          extension = define_extensions(model, name, &block)
          options[:extend] = [*options[:extend], extension] if extension

          scope = build_scope(scope)

          StrataTables::Reflection.create(macro, name, scope, options, model)
        end

        def self.valid_options(options)
          super | [:klass]
        end
      end
    end
  end
end
