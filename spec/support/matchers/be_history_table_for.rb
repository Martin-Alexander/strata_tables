require "rspec/expectations"

RSpec::Matchers.define :be_history_table_for do |temporal_table_name|
  match(notify_expectation_failures: true) do |table|
    conn = table.conn

    temporal_table = StrataTables::TableWrapper.new(conn, temporal_table_name)

    expect(temporal_table).to be_present
    expect(table).to have_attributes(primary_key: "version_id")
    expect(table).to have_column(:sys_period, :tstzrange, null: false)

    %i[insert update delete].each do |verb|
      expect(temporal_table).to have_trigger("on_#{verb}_strata_trigger")
      expect(temporal_table).to have_history_callback_function(verb)
    end

    expect(conn.execute("SELECT * FROM strata_metadata"))
      .to contain_exactly(
        "history_table" => table.table_name.to_s,
        "temporal_table" => temporal_table.to_s
      )
  end
end
