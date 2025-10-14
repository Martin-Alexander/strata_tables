require "rspec/expectations"

RSpec::Matchers.define :have_history_table do
  match do |table|
    history_table = "#{table}__history"

    expect(history_table).to have_column(:id, :integer)
      .and(have_column(:validity, :tstzrange, null: false))

    expect(table)
      .to have_trigger(:on_insert_strata_trigger)
      .and(have_trigger(:on_update_strata_trigger))
      .and(have_trigger(:on_delete_strata_trigger))

    expect(conn)
      .to have_history_callback_function(table, :insert)
      .and(have_history_callback_function(table, :update))
      .and(have_history_callback_function(table, :delete))
  end
end
