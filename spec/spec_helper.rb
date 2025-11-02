require "active_record"
require "debug"
require "niceql"

require "strata_tables"

require "support/associations"
require "support/connection_extensions"
require "support/db_config"
require "support/matchers/be_history_table_for"
require "support/matchers/have_column"
require "support/matchers/has_exclusion_constraint"
require "support/matchers/have_function"
require "support/matchers/have_history_callback_function"
require "support/matchers/have_loaded"
require "support/matchers/have_table"
require "support/matchers/have_trigger"
require "support/model_factory"
require "support/record_factory"
require "support/timestamping_helper"
require "support/transaction_helper"

ActiveRecord::Base.establish_connection(DbConfig.get)
ActiveRecord::Base.logger = Logger.new($stdout) if ENV.fetch("AR_LOG") { false }

RSpec.configure do |config|
  config.include TransactionHelper
  config.include TimestampingHelper
  config.include ModelFactory
  config.extend RecordFactory
  config.include StrataTables

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

  def truncate_all_tables(except: [])
    except.map!(&:to_s)

    tables = conn.tables.reject { |t| except.include?(t) }

    truncate_tables(tables)
  end

  def truncate_tables(tables)
    conn.truncate_tables(*tables)
  end

  def conn
    ActiveRecord::Base.connection.tap do |connection|
      connection.extend(StrataTables::ConnectionExtensions)
    end
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

  def p_sql(string)
    puts(Niceql::Prettifier.prettify_sql(string))
  end
end
