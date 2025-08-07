require "rspec/expectations"

RSpec::Matchers.define :have_strata_functions do |strata_table|
  chain :for_columns do |column_names|
    @column_names = column_names
  end

  match do |connection|
    function_names = [
      "#{strata_table}_insert",
      "#{strata_table}_update",
      "#{strata_table}_delete"
    ]

    results = connection.execute(<<~SQL)
      SELECT
        p.proname as function_name,
        obj_description(p.oid) as comment
      FROM pg_proc p 
      WHERE p.proname in (#{function_names.map { |name| "'#{name}'" }.join(", ")}) 
    SQL

    if results.count != 3 || results.map { |row| row["function_name"] }.difference(function_names).any?
      return false
    end

    if @column_names
      column_names_match = results
        .reject { |row| row["function_name"] == "#{strata_table}_delete" }
        .map { |row| row["comment"] }
        .all? { |comment| comment == {columns: @column_names}.to_json }

      if !column_names_match
        return false
      end
    end

    true
  end

  description do
    if @column_names
      "have strata functions for table '#{strata_table}' with column names #{@column_names}"
    else
      "have strata functions for table '#{strata_table}'"
    end
  end

  failure_message do |connection|
    if @column_names
      "expected db to have strata functions for table '#{strata_table}' with column names #{@column_names}"
    else
      "expected db to have strata functions for table '#{strata_table}'"
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
