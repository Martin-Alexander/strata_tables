require "rspec/expectations"

RSpec::Matchers.define :have_function do |name|
  match do |connection|
    expect(connection.function_exists?(name)).to be(true)
  end
end

RSpec::Matchers.define_negated_matcher :not_have_function, :have_function
