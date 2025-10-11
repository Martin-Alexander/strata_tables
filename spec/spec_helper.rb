require "active_record"
require "debug"
require "yaml"

require "strata_tables"

require "support/matchers/have_temporal_table"
require "support/matchers/have_column"
require "support/matchers/have_function"
require "support/matchers/have_table"
require "support/matchers/have_trigger"
require "support/transaction_helper"

db_config_path = ENV.fetch("DATABASE_CONFIG") { "spec/support/database.yml" }
db_config = YAML.load_file(db_config_path)["test"]
ActiveRecord::Base.establish_connection(db_config)
ActiveRecord::Base.logger = Logger.new($stdout) if ENV.fetch("AR_LOG") { false }

RSpec.configure do |config|
  config.include TransactionHelper
  config.include StrataTables

  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  RSpec::Matchers.alias_matcher :have_attrs, :have_attributes

  PlPgsqlFunction = Struct.new(:name, :body)

  def conn
    ActiveRecord::Base.connection
  end

  def randomize_sequences!(*columns)
    conn.tables.each do |table|
      next if table == "schema_migrations" || table == "ar_internal_metadata"

      columns.each do |column|
        sequence_name = conn.execute(
          "SELECT pg_get_serial_sequence('#{table}', '#{column}')"
        ).first&.fetch("pg_get_serial_sequence")

        if sequence_name
          offset = Math.exp(2 + rand * (10 - 2)).to_i
          conn.execute("SELECT setval('#{sequence_name}', #{offset})")
        end
      rescue ActiveRecord::StatementInvalid
      end
    end
  end

  def plpgsql_functions
    rows = conn.execute(<<~SQL.squish)
      SELECT p.proname AS function_name,
        pg_get_functiondef(p.oid) AS function_definition
      FROM pg_proc p
      JOIN pg_namespace n ON p.pronamespace = n.oid
      WHERE p.prolang = (SELECT oid FROM pg_language WHERE lanname = 'plpgsql')
          AND n.nspname NOT IN ('pg_catalog', 'information_schema');
    SQL

    rows.map { |row| PlPgsqlFunction.new(*row.values) }
  end
end
