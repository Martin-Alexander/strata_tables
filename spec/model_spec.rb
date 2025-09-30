require "spec_helper"

RSpec.describe StrataTables::Model do
  before do
    conn.create_table(:products)
    conn.create_table(:products_versions)
  end

  after do
    conn.drop_table(:products, if_exists: true)
    conn.drop_table(:products_versions, if_exists: true)
  end

  let(:product_class) do
    application_record_class = Class.new(ActiveRecord::Base) do
      self.abstract_class = true

      include StrataTables::Model
    end

    Class.new(application_record_class) do
      self.table_name = "products"
    end
  end

  let(:product_version_class) do
    Class.new(product_class) do
      include StrataTables::Models::Version
    end
  end

  describe "::table_name" do
    context "when there is a versions table" do
      it "returns the version table" do
        expect(product_version_class.table_name).to eq("products_versions")
      end
    end

    context "when there is only a regular table" do
      before { conn.drop_table(:products_versions) }

      it "returns the version table" do
        expect(product_version_class.table_name).to eq("products")
      end
    end
  end
end
