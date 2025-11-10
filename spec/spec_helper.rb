require "active_record"
require "active_support/test_case"
require "active_record/connection_adapters/postgresql_adapter"
require "debug"
require "niceql"

require "strata_tables"

require "support/associations"
require "support/db_config"
require "support/have_versioning_hook"
require "support/model_factory"
require "support/record_factory"
require "support/spec_connection_adapter"
require "support/table_factory"
require "support/transaction_time"

ActiveRecord::Base.establish_connection(StrataTablesTest::DbConfig.get)
ActiveRecord::Base.logger = Logger.new($stdout) if ENV.fetch("AR_LOG") { false }

RSpec.configure do |config|
  config.include ActiveSupport::Testing::TimeHelpers
  config.include StrataTablesTest::Associations
  config.include StrataTablesTest::ModelFactory
  config.include StrataTablesTest::RecordFactory
  config.include StrataTablesTest::TableFactory
  config.include StrataTablesTest::TransactionTime

  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  def drop_all_tables
    conn.tables.each { |table| conn.drop_table(table, force: :cascade) }
  end

  def drop_all_versioning_hooks
    functions = spec_conn.plpgsql_functions

    return if functions.empty?

    function_names = functions.map { "#{_1.name}()" }.join(", ")

    conn.execute("DROP FUNCTION #{function_names} CASCADE")
  end

  def conn
    ActiveRecord::Base.connection
  end

  def spec_conn
    db_config = StrataTablesTest::DbConfig.get

    @spec_conn ||= StrataTablesTest::SpecConnectionAdapter.new(db_config)
  end

  def p_sql(relation)
    puts(Niceql::Prettifier.prettify_sql(relation.to_sql))
  end
end
