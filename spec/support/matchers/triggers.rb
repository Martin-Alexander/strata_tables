require "rspec/expectations"

RSpec::Matchers.define :have_trigger do |table, function_name|
  match do |connection|
    result = connection.execute(<<~SQL)
      SELECT COUNT(*) 
      FROM pg_trigger t 
      JOIN pg_proc p ON t.tgfoid = p.oid 
      WHERE p.proname = '#{function_name}'
      AND t.tgrelid = '#{table}'::regclass::oid
    SQL

    result.first["count"].to_i > 0
  end

  description do
    "have trigger #{function_name.inspect} on #{table.inspect}"
  end

  failure_message do |connection|
    "expected to have trigger #{function_name.inspect} on #{table.inspect}"
  end

  failure_message_when_negated do |connection|
    "expected to not have trigger #{function_name.inspect} on #{table.inspect}"
  end
end
