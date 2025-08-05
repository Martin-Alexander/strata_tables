require "rspec/expectations"

RSpec::Matchers.define :have_columns do |table, columns|
  match do |connection|
    columns.all? do |(column, type)|
      connection.column_exists?(table, column, type)
    end
  end

  description do
    "have table '#{table}' with columns #{columns.inspect}"
  end

  failure_message do |connection|
    "expected db to have table '#{table}' with columns #{columns.inspect}"
  end

  failure_message_when_negated do |connection|
    "expected db to not have table '#{table}' with columns #{columns.inspect}"
  end
end
