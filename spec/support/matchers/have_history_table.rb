require "rspec/expectations"

RSpec::Matchers.define :have_history_table do
  match do |table|
    correct_columns(table) &&
      correct_triggers(table) &&
      correct_functions(table)
  end

  private

  def correct_columns(table)
    history_table = "#{table}_versions"

    have_column(:id, :integer).matches?(history_table) &&
      have_column(:validity, :tstzrange, null: false).matches?(history_table)
  end

  def correct_triggers(table)
    have_trigger(:on_insert_strata_trigger).matches?(table) &&
      have_trigger(:on_update_strata_trigger).matches?(table) &&
      have_trigger(:on_delete_strata_trigger).matches?(table)
  end

  def correct_functions(table)
    history_table = "#{table}_versions"

    have_function("#{history_table}_insert").matches?(conn) &&
      have_function("#{history_table}_update").matches?(conn) &&
      have_function("#{history_table}_delete").matches?(conn)
  end
end
