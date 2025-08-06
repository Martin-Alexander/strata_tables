require "spec_helper"

RSpec.describe StrataTables::ActiveRecord::CommandRecorder do
  let(:recorder) { ActiveRecord::Migration::CommandRecorder.new(ActiveRecord::Base.connection) }

  describe "#inverse_of" do
    context "given a create_strata_triggers command" do
      it "returns a drop_strata_triggers command" do
        inverse = recorder.inverse_of(:create_strata_triggers, [:strata_books, :books, [:id, :title, :pages]])

        expect(inverse).to eq([:drop_strata_triggers, [:strata_books, :books, [:id, :title, :pages]]])
      end
    end

    context "given a drop_strata_triggers command" do
      it "returns a create_strata_triggers command" do
        inverse = recorder.inverse_of(:drop_strata_triggers, [:strata_books, :books, [:id, :title, :pages]])

        expect(inverse).to eq([:create_strata_triggers, [:strata_books, :books, [:id, :title, :pages]]])
      end
    end

    context "given a add_column_to_strata_triggers command" do
      it "returns a remove_column_from_strata_triggers command" do
        inverse = recorder.inverse_of(:add_column_to_strata_triggers, [:strata_books, :books, :author_id])

        expect(inverse).to eq([:remove_column_from_strata_triggers, [:strata_books, :books, :author_id]])
      end
    end

    context "given a remove_column_from_strata_triggers command" do
      it "returns a add_column_to_strata_triggers command" do
        inverse = recorder.inverse_of(:remove_column_from_strata_triggers, [:strata_books, :books, :author_id])

        expect(inverse).to eq([:add_column_to_strata_triggers, [:strata_books, :books, :author_id]])
      end
    end
  end
end
