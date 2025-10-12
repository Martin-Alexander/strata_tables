require "spec_helper"

RSpec.describe StrataTables::Migration::CommandRecorder do
  let(:recorder) { ActiveRecord::Migration::CommandRecorder.new(ActiveRecord::Base.connection) }

  describe "#inverse_of" do
    context "given a create_history_table command" do
      it "returns a drop_history_table command" do
        inverse = recorder.inverse_of(:create_history_table, [:books])
        expect(inverse).to eq([:drop_history_table, [:books]])

        inverse = recorder.inverse_of(:create_history_table, [:books, {except: [:x]}])
        expect(inverse).to eq([:drop_history_table, [:books, {except: [:x]}]])
      end
    end

    context "given a drop_history_table command" do
      it "returns a create_history_table command" do
        inverse = recorder.inverse_of(:drop_history_table, [:books])
        expect(inverse).to eq([:create_history_table, [:books]])

        inverse = recorder.inverse_of(:drop_history_table, [:books, {except: [:x]}])
        expect(inverse).to eq([:create_history_table, [:books, {except: [:x]}]])
      end
    end
  end
end
