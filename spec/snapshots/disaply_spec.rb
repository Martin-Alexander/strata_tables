require "spec_helper"

RSpec.describe StrataTables::Snapshots::Display do
  subject { snapshot(Product, t) }

  before do
    subject.load_schema
  end

  let(:t) { get_time }

  product_class_attr_list = "id: integer, name: string, price: integer, category_id: integer, validity: tsrange"
  product_instance_attr_list = "id: nil, name: nil, price: nil, category_id: nil, validity: nil"

  describe "::to_s" do
    it "returns {model.name}Snapshot" do
      expect(subject.to_s).to eq("ProductSnapshot@#{t.iso8601}")
    end
  end

  describe "::inspect" do
    it "returns {model.name}Snapshot({attr_list})" do
      expect(subject.inspect).to eq("ProductSnapshot@#{t.iso8601}(#{product_class_attr_list})")
    end

    context "if the schema is not loaded" do
      before do
        allow(subject).to receive(:schema_loaded?).and_return(false)
      end

      it "returns {model.name}Snapshot@({time})" do
        expect(subject.inspect).to eq("ProductSnapshot@#{t.iso8601}")
      end
    end
  end

  describe "::pretty_print" do
    it "returns {model.name}Snapshot({attr_list})" do
      output = StringIO.new
      PP.pp(subject, output)
      string = output.string.delete("\n")

      expect(string).to eq("ProductSnapshot@#{t.iso8601}(#{product_class_attr_list})")
    end
  end

  describe "#to_s" do
    it "returns #<{model.name}Snapshot{address}>" do
      expect(subject.new.to_s).to match(/^#<ProductSnapshot@#{t.iso8601}:0x[0-9a-f]+>/)
    end
  end

  describe "#inspect" do
    it "returns #<{model.name}Snapshot {attr_list}>" do
      expect(subject.new.inspect).to eq("#<ProductSnapshot@#{t.iso8601} #{product_instance_attr_list}>")
    end
  end

  describe "#pretty_print" do
    it "returns #<{model.name}Snapshot {attr_list}>" do
      output = StringIO.new
      PP.pp(subject.new, output)
      string = output.string.delete("\n")

      expect(string).to eq("#<ProductSnapshot@#{t.iso8601} #{product_instance_attr_list}>")
    end
  end
end
