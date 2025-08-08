require "rspec/expectations"

RSpec::Matchers.define :have_table do |table|
  match do |connection|
    connection.table_exists?(table)
  end
end

RSpec::Matchers.define_negated_matcher :not_have_table, :have_table
