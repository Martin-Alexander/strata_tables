require "rspec/expectations"

RSpec::Matchers.define :have_strata_triggers do |table|
  match do |connection|
    result = connection.execute(<<~SQL)
      SELECT COUNT(DISTINCT t.tgname) as count
      FROM pg_trigger t 
      WHERE t.tgname IN ('on_insert_strata_trigger', 'on_update_strata_trigger', 'on_delete_strata_trigger')
        AND t.tgrelid = '#{table}'::regclass::oid
    SQL

    result.first["count"].to_i == 3
  end

  description do
    "have table '#{table}' with strata triggers"
  end

  failure_message do |connection|
    "expected db to have table '#{table}' with strata triggers"
  end

  failure_message_when_negated do |connection|
    "expected db to not have table '#{table}' with strata triggers"
  end
end
