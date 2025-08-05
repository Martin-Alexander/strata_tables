require "spec_helper"

RSpec.describe HistoryTables::ActiveRecord::CommandRecorder do
  let(:recorder) { ActiveRecord::Migration::CommandRecorder.new(ActiveRecord::Base.connection) }

  describe "#inverse_of" do
    context "given a create_history_triggers command" do
      it "returns a drop_history_triggers command" do
        inverse = recorder.inverse_of(:create_history_triggers, [:history_books, :books, [:id, :title, :pages]])

        expect(inverse).to eq([:drop_history_triggers, [:history_books, :books, [:id, :title, :pages]]])
      end
    end

    context "given a drop_history_triggers command" do
      it "returns a create_history_triggers command" do
        inverse = recorder.inverse_of(:drop_history_triggers, [:history_books, :books, [:id, :title, :pages]])

        expect(inverse).to eq([:create_history_triggers, [:history_books, :books, [:id, :title, :pages]]])
      end
    end

    context "given a add_column_to_history_triggers command" do
      it "returns a remove_column_from_history_triggers command" do
        inverse = recorder.inverse_of(:add_column_to_history_triggers, [:history_books, :books, :author_id])

        expect(inverse).to eq([:remove_column_from_history_triggers, [:history_books, :books, :author_id]])
      end
    end

    context "given a remove_column_from_history_triggers command" do
      it "returns a add_column_to_history_triggers command" do
        inverse = recorder.inverse_of(:remove_column_from_history_triggers, [:history_books, :books, :author_id])

        expect(inverse).to eq([:add_column_to_history_triggers, [:history_books, :books, :author_id]])
      end
    end
  end
end
