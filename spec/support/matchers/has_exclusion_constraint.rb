require "rspec/expectations"

RSpec::Matchers.define :have_exclusion_constraint do |expression, options|
  match do |table|
    expect(table.exclusion_constraints).to include(have_attributes(
      expression:,
      options: hash_including(options)
    ))
  end
end
