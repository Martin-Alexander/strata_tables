require "rspec/expectations"

RSpec::Matchers.define :have_trigger do |name|
  match do |table|
    trigger_exists?(table, name)
  end

  private

  def trigger_exists?(table, name)
    result = conn.execute(<<~SQL)
      SELECT 1 as exists
      FROM pg_trigger t 
      WHERE t.tgname = '#{name}'
        AND t.tgrelid = '#{table}'::regclass::oid
      LIMIT 1
    SQL

    result.count > 0
  end
end

RSpec::Matchers.define_negated_matcher :not_have_trigger, :have_trigger
