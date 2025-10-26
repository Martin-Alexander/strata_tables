require "rspec/expectations"

RSpec::Matchers.define :have_column do |name, type, **options|
  match do |table|
    expect(table.column_exists?(name, type, **options)).to be(true)
  end
end

RSpec::Matchers.define_negated_matcher :not_have_column, :have_column
