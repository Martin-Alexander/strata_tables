require "spec_helper"

RSpec.describe StrataTables::ActiveRecord::CommandRecorder do
  let(:recorder) { ActiveRecord::Migration::CommandRecorder.new(ActiveRecord::Base.connection) }

  describe "#inverse_of" do
    context "given a create_strata_table command" do
      it "returns a drop_strata_table command" do
        inverse = recorder.inverse_of(:create_strata_table, [:books])

        expect(inverse).to eq([:drop_strata_table, [:books]])
      end
    end

    context "given a drop_strata_table command" do
      it "returns a create_strata_table command" do
        inverse = recorder.inverse_of(:drop_strata_table, [:books])

        expect(inverse).to eq([:create_strata_table, [:books]])
      end
    end

    context "given a add_strata_column command" do
      it "returns a remove_strata_column command" do
        inverse = recorder.inverse_of(:add_strata_column, [:books, :author_id])

        expect(inverse).to eq([:remove_strata_column, [:books, :author_id]])
      end
    end

    context "given a remove_strata_column command" do
      it "returns a add_strata_column command" do
        inverse = recorder.inverse_of(:remove_strata_column, [:books, :author_id])

        expect(inverse).to eq([:add_strata_column, [:books, :author_id]])
      end
    end
  end
end
