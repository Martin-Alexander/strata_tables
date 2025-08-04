require "rspec/expectations"

RSpec::Matchers.define :have_function do |function_name|
  match do |connection|
    result = connection.execute(<<~SQL)
      SELECT COUNT(*) 
      FROM pg_proc p 
      JOIN pg_namespace n ON p.pronamespace = n.oid 
      WHERE p.proname = '#{function_name}' 
      AND n.nspname = 'public'
    SQL
    result.first["count"].to_i > 0
  end

  description do
    "have function #{function_name}"
  end

  failure_message do |connection|
    "expected database to have function '#{function_name}'"
  end

  failure_message_when_negated do |connection|
    "expected database to not have function '#{function_name}'"
  end
end