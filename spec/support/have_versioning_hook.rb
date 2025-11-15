require "rspec/expectations"

RSpec::Matchers.define :have_versioning_hook do |history_table, columns|
  match(notify_expectation_failures: true) do |source_table|
    function_names = test_conn.plpgsql_functions.map(&:name)

    insert_id = Digest::SHA256.hexdigest("#{source_table}_insert").first(10)
    update_id = Digest::SHA256.hexdigest("#{source_table}_update").first(10)
    delete_id = Digest::SHA256.hexdigest("#{source_table}_delete").first(10)

    expect(function_names).to include(
      "sys_ver_func_#{insert_id}",
      "sys_ver_func_#{update_id}",
      "sys_ver_func_#{delete_id}"
    )

    expect(test_conn.triggers(source_table)).to contain_exactly(
      "versioning_insert_trigger",
      "versioning_update_trigger",
      "versioning_delete_trigger"
    )

    versioning_hook = conn.versioning_hook(source_table)

    expect(versioning_hook).to have_attributes(
      source_table: source_table.to_s,
      history_table: history_table.to_s,
      columns: contain_exactly(*columns.map(&:to_s))
    )
  end
end

RSpec::Matchers.define_negated_matcher :not_have_versioning_hook, :have_versioning_hook
