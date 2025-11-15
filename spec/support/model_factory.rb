module ActiveRecordTemporalTests
  module ModelFactory
    def model(name, super_class = ActiveRecord::Base, as_of: false, &block)
      klass = Class.new(super_class)

      stub_const(name, klass)

      if as_of
        klass.include AsOfQuery
        klass.time_dimensions = :period
      end

      klass.class_eval(&block) if block

      klass
    end
  end
end
