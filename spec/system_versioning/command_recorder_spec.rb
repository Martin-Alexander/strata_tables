require "spec_helper"

RSpec.describe "command recorder" do
  let(:recorder) { ActiveRecord::Migration::CommandRecorder.new(ActiveRecord::Base.connection) }

  describe "#inverse_of" do
    context "given a create_history_table command" do
      it "returns a create_history_table_for command" do
        expect(recorder.inverse_of(:create_history_table_for, [:books]))
          .to eq([:drop_history_table_for, [:books]])

        expect(recorder.inverse_of(:create_history_table_for, [:books, :book_history]))
          .to eq([:drop_history_table_for, [:books, :book_history]])

        expect(recorder.inverse_of(:create_history_table_for, [:books, {except: [:created_at]}]))
          .to eq([:drop_history_table_for, [:books, {except: [:created_at]}]])
      end
    end

    context "given a drop_history_table_for command" do
      it "returns a create_history_table_for command" do
        expect(recorder.inverse_of(:drop_history_table_for, [:books]))
          .to eq([:create_history_table_for, [:books]])

        expect(recorder.inverse_of(:drop_history_table_for, [:books, :book_history]))
          .to eq([:create_history_table_for, [:books, :book_history]])

        expect(recorder.inverse_of(:drop_history_table_for, [:books, {except: [:created_at]}]))
          .to eq([:create_history_table_for, [:books, {except: [:created_at]}]])
      end
    end
  end
end
