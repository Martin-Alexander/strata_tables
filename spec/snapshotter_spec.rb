require "spec_helper"

RSpec.describe StrataTables::Snapshotter do
  subject { described_class.new }

  describe "#snapshot_at" do
    it "yields the given block" do
      callee = double(call: nil)

      subject.snapshot_at(get_time) do
        callee.call
      end

      expect(callee).to have_received(:call)
    end
  end
end
