require "rspec/expectations"

RSpec::Matchers.define :have_temporal_table do
  match do |table|
    correct_columns(table) &&
      correct_triggers(table) &&
      correct_functions(table)
  end

  private

  def correct_columns(table)
    temporal_table = "#{table}_versions"

    have_column(:id, :integer).matches?(temporal_table) &&
      have_column(:validity, :tstzrange, null: false).matches?(temporal_table)
  end

  def correct_triggers(table)
    have_trigger(:on_insert_strata_trigger).matches?(table) &&
      have_trigger(:on_update_strata_trigger).matches?(table) &&
      have_trigger(:on_delete_strata_trigger).matches?(table)
  end

  def correct_functions(table)
    temporal_table = "#{table}_versions"

    have_function("#{temporal_table}_insert").matches?(conn) &&
      have_function("#{temporal_table}_update").matches?(conn) &&
      have_function("#{temporal_table}_delete").matches?(conn)
  end
end
