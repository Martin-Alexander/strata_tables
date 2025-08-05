require "rspec/expectations"

RSpec::Matchers.define :have_trigger do |table, trigger|
  match do |connection|
    result = connection.execute(<<~SQL)
      SELECT COUNT(*) 
      FROM pg_trigger t 
      WHERE
        t.tgname = '#{trigger}' AND
        t.tgrelid = '#{table}'::regclass::oid
    SQL

    result.first["count"].to_i > 0
  end

  description do
    "have table '#{table}' with trigger '#{trigger}'"
  end

  failure_message do |connection|
    "expected db to have table '#{table}' with trigger '#{trigger}'"
  end

  failure_message_when_negated do |connection|
    "expected db to not have table '#{table}' with trigger '#{trigger}'"
  end
end
