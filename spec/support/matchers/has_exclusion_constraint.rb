require "rspec/expectations"

RSpec::Matchers.define :have_exclusion_constraint do |expression, options|
  match do |table_name|
    exclusion_constraints = conn.exclusion_constraints(table_name)

    expect(exclusion_constraints).to include(have_attributes(
      table_name:,
      expression:,
      options: hash_including(options)
    ))
  end
end
