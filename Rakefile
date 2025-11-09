require "bundler/gem_tasks"
require "rspec/core/rake_task"

RSpec::Core::RakeTask.new(:spec)

require "standard/rake"

task default: %i[spec standard]

require "active_record"
require_relative "spec/support/db_config"
require_relative "lib/strata_tables"

namespace :db do
  desc "Create test database"
  task :create do
    ActiveRecord::Base.establish_connection(StrataTablesTest::DbConfig.merge(database: :postgres))
    ActiveRecord::Base.connection.create_database(:strata_tables_test)
  end

  desc "Drop test database"
  task :drop do
    ActiveRecord::Base.establish_connection(StrataTablesTest::DbConfig.merge(database: :postgres))
    ActiveRecord::Base.connection.drop_database(:strata_tables_test)
  end
end
