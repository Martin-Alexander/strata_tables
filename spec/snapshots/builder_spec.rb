require "spec_helper"

RSpec.describe StrataTables::Snapshots::Builder do
  it "creates an anonymous class that inherits from the original class" do
    klass = snapshot(Product, get_time)

    expect(klass).to be_a(Class)
    expect(klass).to be < Product
    expect(klass.table_name).to eq("strata_products")
  end
end
