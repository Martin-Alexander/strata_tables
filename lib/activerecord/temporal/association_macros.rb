module ActiveRecord::Temporal
  extend ActiveSupport::Concern

  class_methods do
    def has_many(name, scope = nil, **options, &extension)
    end

    def has_one(name, scope = nil, **options)
    end

    def belongs_to(name, scope = nil, **options)
    end

    def has_and_belongs_to_many(name, scope = nil, **options, &extension)
    end
  end
end