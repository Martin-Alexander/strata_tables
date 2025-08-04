class TsRange
  def self.parse(string)
    return false unless string.is_a?(String)

    ts_range = new

    return ts_range if string == "empty"

    return false unless string =~ /^(\[|\()"?([^,"]*)"?,"?([^\]\)"]*)"?(\]|\))$/

    lower_bracket, lower_val, upper_val, upper_bracket = $1, $2, $3, $4

    ts_range.lower_value = begin
      Time.new(lower_val + " UTC")
    rescue
      nil
    end
    ts_range.lower_inclusive = lower_bracket == "["

    ts_range.upper_value = begin
      Time.new(upper_val + " UTC")
    rescue
      nil
    end
    ts_range.upper_inclusive = upper_bracket == "]"

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
    time.strftime("%Y-%m-%d %H:%M:%S.%N").sub(/0+$/, "")
  end
end
