require "rspec/expectations"

RSpec::Matchers.define :be_tsrange do
  chain :empty do
    @ts_range ||= TsRange.new
  end

  chain :from do |lower_value, inclusive|
    @ts_range ||= TsRange.new

    @ts_range.lower_value = lower_value
    @ts_range.lower_inclusive = inclusive == :inclusive
  end

  chain :to do |upper_value, inclusive|
    @ts_range ||= TsRange.new

    @ts_range.upper_value = upper_value
    @ts_range.upper_inclusive = inclusive == :inclusive
  end

  match do |actual|
    TsRange.parse(actual) == @ts_range
  end

  description do
    "be a tsrange #{@ts_range}"
  end

  failure_message do |actual|
    "expected #{actual} to match #{@ts_range}"
  end
end
