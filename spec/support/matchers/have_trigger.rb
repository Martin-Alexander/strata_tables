require "rspec/expectations"

RSpec::Matchers.define :have_trigger do |name|
  match do |table|
    expect(table.triggers).to include(name)
  end
end

RSpec::Matchers.define_negated_matcher :not_have_trigger, :have_trigger
