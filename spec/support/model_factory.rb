module ModelFactory
  def table(name, as_of: false, &block)
    as_of ? as_of_table(name, &block) : regular_table(name, &block)
  end

  def model(name, as_of: false, &block)
    stub_const(name, Class.new(ActiveRecord::Base) do
      if as_of
        include StrataTables::AsOf

        self.as_of_attribute = :period
      end

      instance_exec(&block) if block
    end)
  end

  def as_of_table(name, &block)
    conn.create_table name, primary_key: :v_id do |t|
      t.bigint :b_id
      t.tstzrange :period, null: false

      instance_exec(t, &block) if block
    end
  end

  def regular_table(name, &block)
    conn.create_table name, primary_key: :b_id do |t|
      instance_exec(t, &block) if block
    end
  end
end
