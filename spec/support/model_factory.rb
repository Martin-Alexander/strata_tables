module StrataTablesTest
  module ModelFactory
    def model(name, super_class = ActiveRecord::Base, as_of: false, &block)
      klass = Class.new(super_class)

      stub_const(name, klass)

      if as_of
        klass.include StrataTables::AsOf
        klass.time_dimension = :period
      end

      klass.class_eval(&block) if block

      klass
    end
  end
end
