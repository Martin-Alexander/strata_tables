require "rspec/expectations"

RSpec::Matchers.define :have_history_callback_function do |verb|
  match do |table|
    function_name = table.history_callback_function_name(verb)

    expect(table.conn).to have_function(function_name)
  end
end

RSpec::Matchers.define_negated_matcher :not_have_history_callback_function, :have_history_callback_function
