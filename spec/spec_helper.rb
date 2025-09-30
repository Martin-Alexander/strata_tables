require "active_record"
require "database_cleaner/active_record"
require "debug"
require "yaml"

require "strata_tables"

require "support/active_record_helper"
require "support/matchers/have_temporal_table"
require "support/matchers/have_column"
require "support/matchers/have_function"
require "support/matchers/have_table"
require "support/matchers/have_trigger"
require "support/transaction_helper"

db_config_path = ENV.fetch("DATABASE_CONFIG") { "spec/support/database.yml" }
db_config = YAML.load_file(db_config_path)["test"]
ActiveRecord::Base.establish_connection(db_config)

DatabaseCleaner.strategy = :transaction
DatabaseCleaner.allow_remote_database_url = true

RSpec.configure do |config|
  config.include ActiveRecordHelper
  config.include TransactionHelper
  config.include StrataTables

  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  def conn
    ActiveRecord::Base.connection
  end

  def get_time
    Time.current
  end
end
