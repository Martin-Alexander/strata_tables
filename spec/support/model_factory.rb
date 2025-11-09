module StrataTablesTest
  module ModelFactory
    def model(name, super_class = ActiveRecord::Base, as_of: false, &block)
      klass = stub_const(name, Class.new(super_class) do
        include StrataTables::AsOf if as_of

        instance_exec(&block) if block
      end)

      klass.time_dimension = :period if as_of

      klass
    end
  end
end
