require "rspec/expectations"

RSpec::Matchers.define :have_function do |name|
  match do |connection|
    function_exists?(connection, name)
  end

  private

  def function_exists?(connection, name)
    result = connection.execute(<<~SQL)
      SELECT 1 as exists
      FROM pg_proc
      WHERE proname = '#{name}'
    SQL

    result.count > 0
  end
end

RSpec::Matchers.define_negated_matcher :not_have_function, :have_function
