require "rspec/expectations"

RSpec::Matchers.define :have_columns do |table, columns|
  match do |connection|
    columns.all? do |(column, type)|
      connection.column_exists?(table, column, type)
    end
  end

  description do
    "have columns #{columns.inspect}"
  end

  failure_message do |connection|
    "expected #{table.inspect} to have columns #{columns.inspect}"
  end

  failure_message_when_negated do |connection|
    "expected #{table.inspect} to not have columns #{columns.inspect}"
  end
end
