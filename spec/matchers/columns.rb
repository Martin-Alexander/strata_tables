require "rspec/expectations"

RSpec::Matchers.define :have_column do |table, column, type = nil|
  match do |connection|
    connection.column_exists?(table, column, type)
  end

  description do
    message = "have #{table} with #{column}"
    message << " with type #{type}" if type
    message
  end

  failure_message do |connection|
    message = "expected #{table} to have a #{column} column"
    message << " with type #{type}" if type
    message
  end

  failure_message_when_negated do |connection|
    message = "expected #{table} to not have a #{column} column"
    message << " with type #{type}" if type
    message
  end
end

RSpec::Matchers.define :have_columns do |table, columns|
  match do |connection|
    columns.all? do |(column, type)|
      connection.column_exists?(table, column, type)
    end
  end

  failure_message do |connection|
    message = "expected #{table} to have columns:\n\t#{columns}"
    message << "\ngot:\n\t#{connection.columns(table).map { |column| [column.name.to_sym, column.type] }}"
    message
  end
end