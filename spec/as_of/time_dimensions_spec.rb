require "spec_helper"

RSpec.describe "time dimensions" do
  before do
    table :cats, primary_key: [:id, :period_1, :period_2] do |t|
      t.bigserial :id
      t.tstzrange :period_1
      t.tstzrange :period_2
    end

    model "Cat" do
      include StrataTables::AsOf
      self.time_dimensions = [:period_1, :period_2, :period_3]
      self.default_time_dimension = :period_2
    end
  end

  after { drop_all_tables }

  t = Time.utc(2000)

  let(:cat) { Cat.new(period_1: t...t+2, period_2: t+2...t+3) }

  describe "#time_dimension" do
    it "returns the value of a given dimension" do
      expect(cat.time_dimension(:period_1)).to eq(t...t+2)
      expect(cat.time_dimension(:period_2)).to eq(t+2...t+3)
    end

    it "without an argument it falls back on the default dimension" do
      expect(cat.time_dimension).to eq(t+2...t+3)
    end

    it "it raises an error of the time dimension is not backed by a column" do
      expect { cat.time_dimension_start(:period_3) }
        .to raise_error(ArgumentError, "no time dimension column 'period_3'")
    end
  end

  describe "#time_dimension_start" do
    it "returns the start value of a given dimension" do
      expect(cat.time_dimension_start(:period_1)).to eq(t)
      expect(cat.time_dimension_start(:period_2)).to eq(t+2)
    end

    it "without an argument it falls back on the default dimension" do
      expect(cat.time_dimension_start).to eq(t+2)
    end

    it "returns nil if the time dimension is nil" do
      cat_2 = Cat.new(period_1: t...t+2)

      expect(cat_2.time_dimension_start(:period_1)).to eq(t)
      expect(cat_2.time_dimension_start(:period_2)).to be_nil
    end

    it "it raises an error if the time dimension doesn't have a column" do
      expect { cat.time_dimension_start(:period_3) }
        .to raise_error(ArgumentError, "no time dimension column 'period_3'")
    end
  end

  describe "#time_dimension_end" do
    it "returns the end value of a given dimension" do
      expect(cat.time_dimension_end(:period_1)).to eq(t+2)
      expect(cat.time_dimension_end(:period_2)).to eq(t+3)
    end
  end

  describe "#set_time_dimension=" do
    it "sets the given time dimension" do
      cat.set_time_dimension(:period_1, t+5...t+6)

      expect(cat.period_1).to eq(t+5...t+6)
    end

    it "without an argument it falls back on the default dimension" do
      cat.set_time_dimension(t+5...t+6)

      expect(cat.period_1).to eq(t...t+2)
      expect(cat.period_2).to eq(t+5...t+6)
    end

    it "it raises an error if the time dimension doesn't have a column" do
      expect { cat.set_time_dimension(:period_3, t...t+1) }
        .to raise_error(ArgumentError, "no time dimension column 'period_3'")
    end
  end

  describe "#set_time_dimension_start" do
    it "sets the given time dimension start" do
      cat.set_time_dimension_start(:period_1, t-9)

      expect(cat.period_1).to eq(t-9...t+2)
    end

    it "sets the end to nil if the time dimension was nil" do
      cat_2 = Cat.new(period_1: t...t+2)

      cat_2.set_time_dimension_start(:period_2, t-9)

      expect(cat_2.period_2).to eq(t-9...nil)
    end

    it "without an argument it falls back on the default dimension" do
      cat.set_time_dimension_start(t-9)

      expect(cat.period_1).to eq(t...t+2)
      expect(cat.period_2).to eq(t-9...t+3)
    end

    it "it raises an error if the time dimension doesn't have a column" do
      expect { cat.set_time_dimension_start(:period_3, t-9) }
        .to raise_error(ArgumentError, "no time dimension column 'period_3'")
    end
  end

  describe "#set_time_dimension_end" do
    it "sets the given time dimension end" do
      cat.set_time_dimension_end(:period_1, t+9)

      expect(cat.period_1).to eq(t...t+9)
    end
  end
end
