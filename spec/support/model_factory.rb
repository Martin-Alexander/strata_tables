module ModelFactory
  def table(name, &block)
    conn.create_table name, primary_key: :v_id do |t|
      t.bigint :b_id

      instance_exec(t, &block) if block
    end
  end

  def model(name, &block)
    stub_const(name, Class.new(ActiveRecord::Base) do
      include StrataTables::AsOf

      self.primary_key = :v_id
      self.as_of_attribute = :period

      instance_exec(&block) if block
    end)
  end
end
