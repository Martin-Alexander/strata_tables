require "rspec/expectations"

RSpec::Matchers.define :have_column do |name, type, **options|
  match do |table|
    conn.column_exists?(table, name, type, **options)
  end
end

RSpec::Matchers.define_negated_matcher :not_have_column, :have_column
