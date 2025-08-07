require "rspec/expectations"

RSpec::Matchers.define :have_strata_functions do |strata_table|
  match do |connection|
    function_names = [
      "#{strata_table}_insert",
      "#{strata_table}_update",
      "#{strata_table}_delete"
    ]

    function_name_sql_list = "(" + function_names.map { |name| "'#{name}'" }.join(", ") + ")"

    results = connection.execute(<<~SQL)
      SELECT proname
      FROM pg_proc
      WHERE proname in #{function_name_sql_list} 
    SQL

    return false unless results.count == 3

    pronames = results.map { |row| row["proname"] }

    return false if pronames.difference(function_names).any?

    true
  end

  description do
    "have strata functions for table '#{strata_table}'"
  end

  failure_message do |connection|
    "expected db to have strata functions for table '#{strata_table}'"
  end

  failure_message_when_negated do |connection|
    "expected db to not have function '#{function_name}'"
  end
end
