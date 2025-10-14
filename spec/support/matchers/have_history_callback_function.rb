require "rspec/expectations"

RSpec::Matchers.define :have_history_callback_function do |source_table, verb|
  match do |conn|
    function_name = conn.history_callback_function_name(source_table, verb)

    expect(conn).to have_function(function_name)
  end
end

RSpec::Matchers.define_negated_matcher :not_have_history_callback_function, :have_history_callback_function
