module ActiveRecordHelper
  def setup_model(name, parent_klass = ActiveRecord::Base, &block)
    klass = Class.new(parent_klass)

    klass.class_eval(&block) if block_given?

    stub_const(name, klass)
  end

  def setup_version_model(model_klass_name, &block)
    model_klass = model_klass_name.constantize

    klass = setup_model("#{model_klass.name}::Version", model_klass) do
      self.table_name = "#{model_klass.table_name}_versions"
    end

    klass.class_eval(&block) if block_given?
  end

  def setup_tables(name, &block)
    conn.create_table(name, &block)
    conn.create_temporal_table(name)
  end

  def teardown_tables(name)
    conn.drop_table(name)
    conn.drop_temporal_table(name) if conn.table_exists?("#{name}_versions")
  end
end
