require "rspec/expectations"

RSpec::Matchers.define :be_tsrange do
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

  private

  class TsRange
    def self.parse(string)
      return false unless string.is_a?(String)

      return false unless string =~ /^(\[|\()"?([^,"]*)"?,"?([^\]\)"]*)"?(\]|\))$/

      lower_bracket, lower_val, upper_val, upper_bracket = $1, $2, $3, $4

      ts_range = new

      ts_range.lower_value = Time.new(lower_val + " UTC") rescue nil
      ts_range.lower_inclusive = lower_bracket == '['

      ts_range.upper_value = Time.new(upper_val + " UTC") rescue nil
      ts_range.upper_inclusive = upper_bracket == ']'

      ts_range
    end

    attr_accessor :lower_value, :lower_inclusive, :upper_value, :upper_inclusive

    def initialize
      @lower_inclusive = false
      @upper_inclusive = false
    end

    def to_s
      string = ""
      string << (@lower_inclusive ? "[" : "(")
      string << format_time(@lower_value) if @lower_value
      string << ","
      string << format_time(@upper_value) if @upper_value
      string << (@upper_inclusive ? "]" : ")")
      string
    end

    def ==(other)
      @lower_value == other.lower_value &&
      @lower_inclusive == other.lower_inclusive &&
      @upper_value == other.upper_value &&
      @upper_inclusive == other.upper_inclusive
    end

    def format_time(time)
      time.strftime("%Y-%m-%d %H:%M:%S.%N").sub(/0+$/, '')
    end
  end
end