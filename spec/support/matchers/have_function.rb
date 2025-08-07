require "rspec/expectations"

RSpec::Matchers.define :have_function do |function_name|
  chain :without_comment do
    @comment = nil
  end

  chain :with_comment do |comment|
    @comment = comment
  end

  match do |connection|
    result = connection.execute(<<~SQL)
      SELECT
        p.proname,
        obj_description(p.oid) as comment
      FROM pg_proc p 
      WHERE p.proname = '#{function_name}' 
    SQL

    return false unless result.count > 0

    if @comment
      result.first["comment"] == @comment
    else
      true
    end
  end

  description do
    if @comment
      "have function '#{function_name}' with comment '#{@comment}'"
    else
      "have function '#{function_name}'"
    end
  end

  failure_message do |connection|
    if @comment
      "expected db to have function '#{function_name}' with comment '#{@comment}'"
    else
      "expected db to have function '#{function_name}'"
    end
  end

  failure_message_when_negated do |connection|
    if @comment
      "expected db to not have function '#{function_name}' with comment '#{@comment}'"
    else
      "expected db to not have function '#{function_name}'"
    end
  end
end
