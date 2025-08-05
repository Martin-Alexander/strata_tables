require "rspec/expectations"

RSpec::Matchers.define :have_table do |table|
  chain :with_trigger do |trigger_name|
    @with_trigger = have_trigger(table, trigger_name)
  end

  chain :with_columns do |columns|
    @with_columns = have_columns(table, columns)
  end

  match do |connection|
    return false unless connection.table_exists?(table)

    return @with_columns.matches?(connection) if @with_columns
    return @with_trigger.matches?(connection) if @with_trigger

    true
  end

  description do
    description = ["have table '#{table}'"]

    description << @with_columns.description if @with_columns
    description << @with_trigger.description if @with_trigger

    description.join(", ")
  end

  failure_message do |connection|
    description = ["expected db to have table '#{table}'"]

    description << @with_columns.failure_message if @with_columns
    description << @with_trigger.failure_message if @with_trigger

    description.join(", ")
  end

  failure_message_when_negated do |connection|
    description = ["expected db to not have table '#{table}'"]

    description << @with_columns.failure_message_when_negated if @with_columns
    description << @with_trigger.failure_message_when_negated if @with_trigger

    description.join(", ")
  end
end
