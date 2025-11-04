module StrataTablesTest
  module ModelFactory
    def model(name, super_class = ActiveRecord::Base, as_of: false, &block)
      stub_const(name, Class.new(super_class) do
        if as_of
          include StrataTables::AsOf

          self.as_of_attribute = :period
        end

        instance_exec(&block) if block
      end)
    end
  end
end
