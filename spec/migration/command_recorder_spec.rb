require "spec_helper"

RSpec.describe StrataTables::Migration::CommandRecorder do
  let(:recorder) { ActiveRecord::Migration::CommandRecorder.new(ActiveRecord::Base.connection) }

  describe "#inverse_of" do
    context "given a create_temporal_table command" do
      it "returns a drop_temporal_table command" do
        inverse = recorder.inverse_of(:create_temporal_table, [:books])

        expect(inverse).to eq([:drop_temporal_table, [:books]])
      end
    end

    context "given a drop_temporal_table command" do
      it "returns a create_temporal_table command" do
        inverse = recorder.inverse_of(:drop_temporal_table, [:books])

        expect(inverse).to eq([:create_temporal_table, [:books]])
      end
    end
  end
end
