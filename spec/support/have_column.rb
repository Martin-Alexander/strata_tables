require "rspec/expectations"

RSpec::Matchers.define :have_column do |name, type, **options|
  match do |table|
    expect(table.column_exists?(name, type, **options)).to be(true)
  end

  failure_message do |actual|
    "expected column_exists?(#{actual.inspect}, #{name.inspect}, #{type.inspect}, #{options.inspect}) to be true"
  end

  failure_message_when_negated do |actual|
    "expected column_exists?(#{actual.inspect}, #{name.inspect}, #{type.inspect}, #{options.inspect}) to be false"
  end
end

RSpec::Matchers.define_negated_matcher :not_have_column, :have_column
