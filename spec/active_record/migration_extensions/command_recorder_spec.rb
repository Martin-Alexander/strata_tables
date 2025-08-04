require "spec_helper"

RSpec.describe HistoryTables::ActiveRecord::CommandRecorder do
  let(:recorder) { ActiveRecord::Migration::CommandRecorder.new(ActiveRecord::Base.connection) }

  describe "#inverse_of" do
    context "given a create_history_triggers command" do
      it "returns a drop_history_triggers command" do
        inverse = recorder.inverse_of(:create_history_triggers, [:books, :history_books, [:id, :title, :pages]])

        expect(inverse).to eq([:drop_history_triggers, [:history_books, :books, [:id, :title, :pages]]])
      end
    end

    context "given a drop_history_triggers command" do
      it "returns a create_history_triggers command" do
        inverse = recorder.inverse_of(:drop_history_triggers, [:history_books, :books, [:id, :title, :pages]])

        expect(inverse).to eq([:create_history_triggers, [:books, :history_books, [:id, :title, :pages]]])
      end
    end
  end
end
