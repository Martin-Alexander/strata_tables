require "rspec/expectations"

RSpec::Matchers.define :have_strata_table do
  match do |table|
    correct_columns(table) &&
      correct_triggers(table) &&
      correct_functions(table)
  end

  private

  def correct_columns(table)
    strata_table = "strata_#{table}"

    have_column(:id, :integer).matches?(strata_table) &&
      have_column(:validity, :tsrange, null: false).matches?(strata_table)
  end

  def correct_triggers(table)
    have_trigger(:on_insert_strata_trigger).matches?(table) &&
      have_trigger(:on_update_strata_trigger).matches?(table) &&
      have_trigger(:on_delete_strata_trigger).matches?(table)
  end

  def correct_functions(table)
    strata_table = "strata_#{table}"

    have_function("#{strata_table}_insert").matches?(conn) &&
      have_function("#{strata_table}_update").matches?(conn) &&
      have_function("#{strata_table}_delete").matches?(conn)
  end
end
